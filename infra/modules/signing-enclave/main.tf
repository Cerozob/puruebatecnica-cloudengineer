# Wallet signing service (ADR-021, ADR-022, ADR-031).
# Wallet keys are stored encrypted in DynamoDB. The KMS key only allows Decrypt
# when the request carries an attestation document from the approved Nitro
# Enclave image, so the plaintext key exists only inside the enclave.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Instance role (the parent instance; decryption still needs the enclave)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "signer" {
  name               = "${var.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.signer.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "signer" {
  statement {
    sid       = "ReadEncryptedWalletKeys"
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.wallet_keys.arn]
  }

  statement {
    sid       = "DecryptOnlyFromEnclave"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.wallet.arn]
  }
}

resource "aws_iam_role_policy" "signer" {
  name   = "sign"
  role   = aws_iam_role.signer.id
  policy = data.aws_iam_policy_document.signer.json
}

resource "aws_iam_instance_profile" "signer" {
  name = "${var.name}-instance"
  role = aws_iam_role.signer.name
}

# ---------------------------------------------------------------------------
# KMS key: multi-Region, decrypt only with enclave attestation
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "wallet_key" {
  statement {
    sid = "KeyAdministration"
    principals {
      type        = "AWS"
      identifiers = var.key_administrator_role_arns
    }
    actions = [
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Enable*",
      "kms:Disable*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ReplicateKey",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]
    resources = ["*"]
  }

  statement {
    sid = "KeyCeremonyEncryptOnly"
    principals {
      type        = "AWS"
      identifiers = var.key_loader_role_arns
    }
    actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
    resources = ["*"]
  }

  statement {
    sid = "DecryptOnlyFromApprovedEnclave"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.signer.arn]
    }
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEqualsIgnoreCase"
      variable = "kms:RecipientAttestation:ImageSha384"
      values   = [var.enclave_image_sha384]
    }
  }
}

resource "aws_kms_key" "wallet" {
  description             = "Envelope key for wallet signing keys (enclave-only decrypt)"
  multi_region            = true
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.wallet_key.json
  tags                    = var.tags
}

resource "aws_kms_alias" "wallet" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.wallet.key_id
}

resource "aws_kms_replica_key" "wallet_dr" {
  provider                = aws.dr
  description             = "DR replica of the wallet envelope key"
  primary_key_arn         = aws_kms_key.wallet.arn
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.wallet_key.json
  tags                    = var.tags
}

# ---------------------------------------------------------------------------
# Encrypted wallet keys: DynamoDB global table
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "wallet_keys" {
  name                        = "${var.name}-keys"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "wallet_id"
  deletion_protection_enabled = true
  stream_enabled              = true
  stream_view_type            = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "wallet_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  # At-rest encryption uses the AWS managed key. Items are already ciphertext
  # under the enclave-only envelope key, which DynamoDB itself cannot use.
  server_side_encryption {
    enabled = true
  }

  replica {
    region_name            = var.dr_region
    point_in_time_recovery = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Signing instances: EC2 Auto Scaling group with Nitro Enclaves
# (ECS does not document Nitro Enclaves support, so this runs outside ECS)
# ---------------------------------------------------------------------------

resource "aws_launch_template" "signer" {
  name_prefix            = "${var.name}-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = var.security_group_ids

  enclave_options {
    enabled = true
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.signer.arn
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # The AMI starts the enclave image and the vsock proxy to KMS on boot.
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    systemctl enable --now nitro-enclaves-allocator.service
    systemctl enable --now nitro-enclaves-vsock-proxy.service
    systemctl enable --now wallet-signer.service
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = var.name })
  }
}

resource "aws_autoscaling_group" "signer" {
  name_prefix         = "${var.name}-"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.signer.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
    }
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------------------
# VPC Lattice: only approved callers can reach the signer (ADR-017)
# ---------------------------------------------------------------------------

resource "aws_vpclattice_target_group" "signer" {
  name = var.name
  type = "INSTANCE"

  config {
    port           = 8443
    protocol       = "HTTPS"
    vpc_identifier = var.vpc_id

    health_check {
      enabled = true
      path    = "/health"
    }
  }

  tags = var.tags
}

resource "aws_autoscaling_traffic_source_attachment" "signer" {
  autoscaling_group_name = aws_autoscaling_group.signer.name

  traffic_source {
    identifier = aws_vpclattice_target_group.signer.arn
    type       = "vpc-lattice"
  }
}

resource "aws_vpclattice_service" "signer" {
  name      = var.name
  auth_type = "AWS_IAM"
  tags      = var.tags
}

resource "aws_vpclattice_listener" "signer" {
  name               = "https"
  protocol           = "HTTPS"
  port               = 443
  service_identifier = aws_vpclattice_service.signer.id

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.signer.id
      }
    }
  }
}

resource "aws_vpclattice_service_network_service_association" "signer" {
  service_identifier         = aws_vpclattice_service.signer.id
  service_network_identifier = var.lattice_service_network_id
}

data "aws_iam_policy_document" "lattice_auth" {
  statement {
    sid = "OnlyApprovedCallers"
    principals {
      type        = "AWS"
      identifiers = var.allowed_caller_role_arns
    }
    actions   = ["vpc-lattice-svcs:Invoke"]
    resources = ["${aws_vpclattice_service.signer.arn}/*"]
  }
}

resource "aws_vpclattice_auth_policy" "signer" {
  resource_identifier = aws_vpclattice_service.signer.arn
  policy              = data.aws_iam_policy_document.lattice_auth.json
}

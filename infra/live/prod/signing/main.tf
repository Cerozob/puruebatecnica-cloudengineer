# Wallet signing service with Nitro Enclaves (ADR-021). Stays in the prod account (ADR-022).

variable "subnet_ids" {
  description = "Private subnets for the signing instances."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the signing instances."
  type        = list(string)
}

variable "ami_id" {
  description = "AMI with the Nitro Enclaves CLI and the signer service."
  type        = string
}

variable "enclave_image_sha384" {
  description = "PCR0 of the approved enclave image, produced by the pipeline build."
  type        = string
}

variable "iac_role_arn" {
  description = "Pipeline role that administers the key."
  type        = string
}

variable "key_ceremony_role_arn" {
  description = "Role used only during the key ceremony to encrypt existing keys."
  type        = string
}

variable "caller_role_arns" {
  description = "Task roles allowed to request signatures."
  type        = list(string)
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/platform/network/vpc-id"
}

data "aws_ssm_parameter" "lattice_core" {
  name = "/platform/network/lattice-core-id"
}

module "signer" {
  source = "../../../modules/signing-enclave"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  vpc_id                      = data.aws_ssm_parameter.vpc_id.value
  subnet_ids                  = var.subnet_ids
  security_group_ids          = var.security_group_ids
  ami_id                      = var.ami_id
  enclave_image_sha384        = var.enclave_image_sha384
  key_administrator_role_arns = [var.iac_role_arn]
  key_loader_role_arns        = [var.key_ceremony_role_arn]
  lattice_service_network_id  = data.aws_ssm_parameter.lattice_core.value
  allowed_caller_role_arns    = var.caller_role_arns
  dr_region                   = var.dr_region
}

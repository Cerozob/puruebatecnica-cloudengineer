# Organization, OUs and SCPs, deployed in the new management account (ADR-001, ADR-003, ADR-007).
# Control Tower creates the Security OU accounts (Log Archive, Audit); AFT vends the rest (live/aft).

variable "governed_regions" {
  description = "Regions allowed by SCPs and governed by Control Tower: primary and DR."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "log_archive_account_id" {
  description = "Log Archive account created by Control Tower."
  type        = string
}

variable "audit_account_id" {
  description = "Audit account created by Control Tower."
  type        = string
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "controltower.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY", "TAG_POLICY"]
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id
}

# The current account is invited here. No restrictive SCPs: production is
# protected by IAM (read-only humans, IaC-only changes) while it is inventoried.
resource "aws_organizations_organizational_unit" "prod_transitional" {
  name      = "Prod-Transitional"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "nonprod" {
  name      = "NonProd"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = local.root_id
}

# ---------------------------------------------------------------------------
# Guardrail SCP for every OU except production
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "guardrails" {
  statement {
    sid       = "DenyOutsideGovernedRegions"
    effect    = "Deny"
    resources = ["*"]
    not_actions = [
      "iam:*",
      "organizations:*",
      "sts:*",
      "support:*",
      "budgets:*",
      "ce:*",
      "cloudfront:*",
      "route53:*",
      "waf:*",
      "sso:*",
    ]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.governed_regions
    }
  }

  statement {
    sid    = "ProtectAuditAndGovernance"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "config:StopConfigurationRecorder",
      "config:DeleteConfigurationRecorder",
      "config:DeleteDeliveryChannel",
      "securityhub:DisableSecurityHub",
      "organizations:LeaveOrganization",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "NoLongLivedIamCredentials"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
    ]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "guardrails" {
  name        = "nonprod-guardrails"
  description = "Baseline guardrails for every OU except production"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.guardrails.json
}

resource "aws_organizations_policy_attachment" "guardrails" {
  for_each = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    nonprod        = aws_organizations_organizational_unit.nonprod.id
    sandbox        = aws_organizations_organizational_unit.sandbox.id
  }

  policy_id = aws_organizations_policy.guardrails.id
  target_id = each.value
}

# ---------------------------------------------------------------------------
# Mandatory tags (ADR-029)
# ---------------------------------------------------------------------------

resource "aws_organizations_policy" "tags" {
  name = "mandatory-tags"
  type = "TAG_POLICY"
  content = jsonencode({
    tags = {
      environment = {
        tag_key   = { "@@assign" = "environment" }
        tag_value = { "@@assign" = ["prod", "staging", "dev", "sandbox", "shared"] }
      }
      owner     = { tag_key = { "@@assign" = "owner" } }
      component = { tag_key = { "@@assign" = "component" } }
    }
  })
}

resource "aws_organizations_policy_attachment" "tags" {
  policy_id = aws_organizations_policy.tags.id
  target_id = local.root_id
}

# ---------------------------------------------------------------------------
# Control Tower landing zone (governs the regions above)
# ---------------------------------------------------------------------------

resource "aws_controltower_landing_zone" "this" {
  version = "3.3"

  manifest_json = jsonencode({
    governedRegions = var.governed_regions
    organizationStructure = {
      security = { name = "Security" }
      sandbox  = { name = "Sandbox" }
    }
    centralizedLogging = {
      accountId = var.log_archive_account_id
      enabled   = true
      configurations = {
        loggingBucket       = { retentionDays = 365 }
        accessLoggingBucket = { retentionDays = 365 }
      }
    }
    securityRoles    = { accountId = var.audit_account_id }
    accessManagement = { enabled = true }
  })

  depends_on = [aws_organizations_organizational_unit.security, aws_organizations_organizational_unit.sandbox]
}

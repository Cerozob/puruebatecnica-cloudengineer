# Account Factory for Terraform (ADR-004), deployed from the management account
# into the AFT management account. Account requests live in their own repository
# (aft-account-request), one file per account: staging, dev, deployments and the
# Innovation Sandbox pool (ADR-005).

terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "kova-terraform-state"
    key          = "aft/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "ct_management_account_id" {
  description = "New management account (ADR-001)."
  type        = string
}

variable "log_archive_account_id" {
  description = "Control Tower Log Archive account."
  type        = string
}

variable "audit_account_id" {
  description = "Control Tower Audit account."
  type        = string
}

variable "aft_management_account_id" {
  description = "Account in the Infrastructure OU that runs AFT."
  type        = string
}

provider "aws" {
  region = "us-east-1"
}

module "aft" {
  source = "github.com/aws-ia/terraform-aws-control_tower_account_factory?ref=1.23.0"

  ct_management_account_id    = var.ct_management_account_id
  log_archive_account_id      = var.log_archive_account_id
  audit_account_id            = var.audit_account_id
  aft_management_account_id   = var.aft_management_account_id
  ct_home_region              = "us-east-1"
  tf_backend_secondary_region = "us-west-2"

  # Repositories stay on GitHub, connected through CodeConnections (ADR-025).
  vcs_provider                                  = "github"
  account_request_repo_name                     = "kova/aft-account-request"
  global_customizations_repo_name               = "kova/aft-global-customizations"
  account_customizations_repo_name              = "kova/aft-account-customizations"
  account_provisioning_customizations_repo_name = "kova/aft-account-provisioning-customizations"

  aft_feature_cloudtrail_data_events      = false
  aft_feature_enterprise_support          = false
  aft_feature_delete_default_vpcs_enabled = true
}

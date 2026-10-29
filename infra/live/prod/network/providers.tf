variable "region" {
  description = "Primary region."
  type        = string
  default     = "us-east-1"
}

variable "deploy_role_arn" {
  description = "IaC role assumed by the pipeline in the target account (ADR-006)."
  type        = string
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn = var.deploy_role_arn
  }

  # Mandatory tags on every resource (ADR-029).
  default_tags {
    tags = {
      environment = "prod"
      component   = "network"
      owner       = "platform"
      managed-by  = "terraform"
    }
  }
}

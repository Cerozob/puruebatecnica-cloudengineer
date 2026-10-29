terraform {
  required_version = ">= 1.10"

  # One state per account and component (ADR-010). S3 native locking, no DynamoDB lock table.
  backend "s3" {
    bucket       = "kova-terraform-state"
    key          = "prod/data/terraform.tfstate"
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

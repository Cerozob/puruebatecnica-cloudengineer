# OpenSearch Serverless NextGen collection via awscc (ADR-015). Built in parallel
# to the current domain; traffic moves with dual writes and an alias switch.

variable "kms_key_arn" {
  description = "Customer managed key for the collection."
  type        = string
}

variable "vpc_endpoint_id" {
  description = "OpenSearch Serverless VPC endpoint."
  type        = string
}

variable "reader_writer_role_arns" {
  description = "Task roles of the services that use search."
  type        = list(string)
}

provider "awscc" {
  region = var.region

  assume_role = {
    role_arn = var.deploy_role_arn
  }
}

module "search" {
  source = "../../../modules/search-collection"

  name                    = "kova-search"
  kms_key_arn             = var.kms_key_arn
  vpc_endpoint_id         = var.vpc_endpoint_id
  reader_writer_role_arns = var.reader_writer_role_arns
}

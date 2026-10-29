# OpenSearch Serverless collection through the awscc provider (ADR-009, ADR-015).
# awscc is generated from the CloudFormation registry, so new capabilities of
# OpenSearch Serverless NextGen tend to appear here before the aws provider.
# Verify the NextGen-specific properties against the registry schema before use.

terraform {
  required_version = ">= 1.10"

  required_providers {
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

variable "name" {
  description = "Collection name (3-32 lowercase characters)."
  type        = string
}

variable "type" {
  description = "Collection type: SEARCH or VECTORSEARCH."
  type        = string
  default     = "SEARCH"
}

variable "kms_key_arn" {
  description = "Customer managed key for encryption at rest."
  type        = string
}

variable "vpc_endpoint_id" {
  description = "OpenSearch Serverless VPC endpoint; the collection is not public."
  type        = string
}

variable "reader_writer_role_arns" {
  description = "Task roles of the services that read and write the collection."
  type        = list(string)
}

resource "awscc_opensearchserverless_security_policy" "encryption" {
  name = "${var.name}-enc"
  type = "encryption"
  policy = jsonencode({
    Rules       = [{ ResourceType = "collection", Resource = ["collection/${var.name}"] }]
    KmsARN      = var.kms_key_arn
    AWSOwnedKey = false
  })
}

resource "awscc_opensearchserverless_security_policy" "network" {
  name = "${var.name}-net"
  type = "network"
  policy = jsonencode([{
    Rules           = [{ ResourceType = "collection", Resource = ["collection/${var.name}"] }]
    AllowFromPublic = false
    SourceVPCEs     = [var.vpc_endpoint_id]
  }])
}

resource "awscc_opensearchserverless_access_policy" "data" {
  name = "${var.name}-data"
  type = "data"
  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "index"
        Resource     = ["index/${var.name}/*"]
        Permission   = ["aoss:ReadDocument", "aoss:WriteDocument", "aoss:CreateIndex", "aoss:DescribeIndex", "aoss:UpdateIndex"]
      },
    ]
    Principal = var.reader_writer_role_arns
  }])
}

resource "awscc_opensearchserverless_collection" "this" {
  name = var.name
  type = var.type

  depends_on = [
    awscc_opensearchserverless_security_policy.encryption,
    awscc_opensearchserverless_security_policy.network,
  ]
}

output "collection_endpoint" {
  description = "Collection endpoint used by the services."
  value       = awscc_opensearchserverless_collection.this.collection_endpoint
}

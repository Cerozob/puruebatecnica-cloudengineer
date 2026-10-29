variable "name" {
  description = "Name prefix for the signing service resources."
  type        = string
  default     = "wallet-signer"
}

variable "vpc_id" {
  description = "VPC of the signing service."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the signing instances (no internet route needed)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the signing instances."
  type        = list(string)
}

variable "ami_id" {
  description = "Amazon Linux 2023 arm64 AMI with the Nitro Enclaves CLI baked in."
  type        = string
}

variable "instance_type" {
  description = "Nitro-capable, non-burstable instance type (Graviton allowed)."
  type        = string
  default     = "c7g.large"
}

variable "min_size" {
  description = "Minimum instances (one per AZ for availability)."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum instances."
  type        = number
  default     = 6
}

variable "enclave_image_sha384" {
  description = "PCR0 (ImageSha384) of the approved enclave image. Only this image can decrypt wallet keys."
  type        = string
}

variable "key_administrator_role_arns" {
  description = "Roles allowed to administer (not use) the wallet key: the IaC pipeline role."
  type        = list(string)
}

variable "key_loader_role_arns" {
  description = "Roles allowed to encrypt wallet keys during the key ceremony."
  type        = list(string)
}

variable "lattice_service_network_id" {
  description = "VPC Lattice service network where the signing service is published."
  type        = string
}

variable "allowed_caller_role_arns" {
  description = "Task roles of the services allowed to request signatures through VPC Lattice."
  type        = list(string)
}

variable "dr_region" {
  description = "DR region for the DynamoDB replica and the KMS replica key (pilot light, ADR-031)."
  type        = string
}

variable "tags" {
  description = "Extra tags; mandatory tags come from the provider default_tags."
  type        = map(string)
  default     = {}
}

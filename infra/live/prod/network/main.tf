# Production network: adopted with import blocks, never recreated (ADR-008, ADR-020).
# Rule: an import is applied only if `terraform plan` shows no changes.
# The IDs below are placeholders filled in during the inventory (phase 0).

variable "vpc_id" {
  description = "Existing production VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "Existing production VPC CIDR."
  type        = string
}

variable "nat_eip_allocation_id" {
  description = "Elastic IP allowlisted by payment providers. Must never change."
  type        = string
}

variable "nat_gateway_id" {
  description = "Existing NAT gateway."
  type        = string
}

variable "nat_subnet_id" {
  description = "Public subnet of the NAT gateway."
  type        = string
}

import {
  to = aws_vpc.prod
  id = var.vpc_id
}

import {
  to = aws_eip.nat
  id = var.nat_eip_allocation_id
}

import {
  to = aws_nat_gateway.prod
  id = var.nat_gateway_id
}

resource "aws_vpc" "prod" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_nat_gateway" "prod" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.nat_subnet_id

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# New: VPC Lattice service networks (ADR-017, ADR-033). Additive, no impact on
# existing traffic until each service is moved.
# ---------------------------------------------------------------------------

resource "aws_vpclattice_service_network" "core" {
  name      = "kova-core"
  auth_type = "AWS_IAM"
}

resource "aws_vpclattice_service_network" "pci" {
  name      = "kova-pci"
  auth_type = "AWS_IAM"
}

resource "aws_vpclattice_service_network_vpc_association" "core" {
  vpc_identifier             = aws_vpc.prod.id
  service_network_identifier = aws_vpclattice_service_network.core.id
}

# Publish the IDs for other components (no cross-state coupling).
resource "aws_ssm_parameter" "lattice_core" {
  name  = "/platform/network/lattice-core-id"
  type  = "String"
  value = aws_vpclattice_service_network.core.id
}

resource "aws_ssm_parameter" "lattice_pci" {
  name  = "/platform/network/lattice-pci-id"
  type  = "String"
  value = aws_vpclattice_service_network.pci.id
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/platform/network/vpc-id"
  type  = "String"
  value = aws_vpc.prod.id
}

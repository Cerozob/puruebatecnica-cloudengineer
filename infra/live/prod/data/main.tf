# Production databases: imported as-is (ADR-008) plus the pilot light replica
# in the DR region (ADR-031). One block per database; this is the pattern.

variable "ledger_db_identifier" {
  description = "Existing RDS instance identifier (example: the ledger database)."
  type        = string
}

variable "ledger_db_engine" {
  description = "Engine of the existing instance, from the inventory."
  type        = string
}

variable "ledger_db_instance_class" {
  description = "Current instance class; rightsizing comes later with Blue/Green (ADR-014)."
  type        = string
}

variable "dr_kms_key_arn" {
  description = "KMS key in the DR region for the encrypted replica."
  type        = string
}

import {
  to = aws_db_instance.ledger
  id = var.ledger_db_identifier
}

resource "aws_db_instance" "ledger" {
  identifier          = var.ledger_db_identifier
  engine              = var.ledger_db_engine
  instance_class      = var.ledger_db_instance_class
  multi_az            = true
  storage_encrypted   = true
  deletion_protection = true
  skip_final_snapshot = false

  # Attributes not managed yet are ignored until the import shows a clean plan.
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [password, allocated_storage, max_allocated_storage]
  }
}

# Pilot light: cross-Region read replica, promoted only during a failover.
resource "aws_db_instance" "ledger_dr" {
  provider = aws.dr

  identifier          = "${var.ledger_db_identifier}-dr"
  replicate_source_db = aws_db_instance.ledger.arn
  instance_class      = var.ledger_db_instance_class
  storage_encrypted   = true
  kms_key_id          = var.dr_kms_key_arn
  deletion_protection = true
  skip_final_snapshot = true
}

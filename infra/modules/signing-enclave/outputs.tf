output "kms_key_arn" {
  description = "Multi-Region envelope key for wallet keys."
  value       = aws_kms_key.wallet.arn
}

output "wallet_keys_table_name" {
  description = "DynamoDB global table with the encrypted wallet keys."
  value       = aws_dynamodb_table.wallet_keys.name
}

output "lattice_service_arn" {
  description = "VPC Lattice service that exposes the signer."
  value       = aws_vpclattice_service.signer.arn
}

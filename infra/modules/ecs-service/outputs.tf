output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_role_arn" {
  description = "Task role ARN, used in VPC Lattice auth policies of the services this one calls."
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  description = "Log group of the service."
  value       = aws_cloudwatch_log_group.this.name
}

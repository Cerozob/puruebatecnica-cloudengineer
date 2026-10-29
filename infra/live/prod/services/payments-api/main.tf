# Example service deployment using the ecs-service module.
# ECS services are rebuilt in Terraform (not imported) and switched with blue/green (ADR-008).

variable "cluster_arn" {
  description = "ECS cluster of the payments domain."
  type        = string
}

variable "image" {
  description = "Image built by the pipeline in the Deployments account (ECR, arm64)."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Service security groups."
  type        = list(string)
}

variable "blue_green" {
  description = "ALB target groups, listener rule and infrastructure role for blue/green."
  type = object({
    production_target_group_arn = string
    alternate_target_group_arn  = string
    production_listener_rule    = string
    infrastructure_role_arn     = string
    bake_time_in_minutes        = optional(number, 10)
  })
}

variable "ledger_db_secret_arn" {
  description = "Database credentials in Secrets Manager (ADR-024)."
  type        = string
}

variable "payments_queue_arn" {
  description = "Example of the only queue this service writes to."
  type        = string
}

data "aws_iam_policy_document" "task" {
  statement {
    sid       = "PublishPaymentEvents"
    actions   = ["sqs:SendMessage"]
    resources = [var.payments_queue_arn]
  }
}

module "payments_api" {
  source = "../../../../modules/ecs-service"

  name               = "payments-api"
  cluster_arn        = var.cluster_arn
  image              = var.image
  cpu                = 1024
  memory             = 2048
  min_count          = 3
  max_count          = 15
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  blue_green         = var.blue_green

  secrets = {
    DB_CREDENTIALS = var.ledger_db_secret_arn
  }

  task_role_policy_json = data.aws_iam_policy_document.task.json
  log_retention_days    = 30
}

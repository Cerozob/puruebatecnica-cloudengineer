variable "name" {
  description = "Service name; also used as the container name and log group suffix."
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster that runs the service."
  type        = string
}

variable "image" {
  description = "Container image URI (ECR, multi-arch or arm64)."
  type        = string
}

variable "cpu" {
  description = "Task CPU units, sized from real metrics (Compute Optimizer)."
  type        = number
  default     = 512
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 1024
}

variable "container_port" {
  description = "Port the application listens on."
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Initial number of tasks; autoscaling adjusts it afterwards."
  type        = number
  default     = 2
}

variable "min_count" {
  description = "Minimum number of tasks for autoscaling."
  type        = number
  default     = 2
}

variable "max_count" {
  description = "Maximum number of tasks for autoscaling."
  type        = number
  default     = 10
}

variable "cpu_target" {
  description = "Average CPU utilization target for autoscaling."
  type        = number
  default     = 60
}

variable "cpu_architecture" {
  description = "ARM64 (Graviton) by default; X86_64 only for images that cannot be built for ARM."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be ARM64 or X86_64."
  }
}

variable "spot_weight" {
  description = "Share of tasks on Fargate Spot (0 = none). Only for interruption-tolerant services."
  type        = number
  default     = 0
}

variable "subnet_ids" {
  description = "Private subnets for the tasks."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the tasks."
  type        = list(string)
}

variable "environment" {
  description = "Plain (non-secret) environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of environment variable name to Secrets Manager or SSM parameter ARN."
  type        = map(string)
  default     = {}
}

variable "task_role_policy_json" {
  description = "Least-privilege IAM policy for the application (only the actions and resources it uses)."
  type        = string
}

variable "log_retention_days" {
  description = "Every log group has a retention period (ADR-028)."
  type        = number
  default     = 30
}

variable "otel_collector_image" {
  description = "ADOT collector sidecar image; the app sends OTLP to localhost (ADR-027)."
  type        = string
  default     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
}

variable "blue_green" {
  description = "ALB resources for ECS native blue/green deployments (ADR-026). Null keeps a rolling deployment."
  type = object({
    production_target_group_arn = string
    alternate_target_group_arn  = string
    production_listener_rule    = string
    infrastructure_role_arn     = string
    bake_time_in_minutes        = optional(number, 10)
  })
  default = null
}

variable "lattice_target_group_arn" {
  description = "VPC Lattice target group that receives service-to-service traffic (ADR-017). Null if not exposed through Lattice."
  type        = string
  default     = null
}

variable "lattice_infrastructure_role_arn" {
  description = "ECS infrastructure role that manages the VPC Lattice registration."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags; mandatory tags come from the provider default_tags (ADR-029)."
  type        = map(string)
  default     = {}
}

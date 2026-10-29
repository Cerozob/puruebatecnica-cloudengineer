# Worked example: one ECS service following the target platform decisions.
# - Fargate on Graviton (ARM64), optional Fargate Spot share (ADR-013)
# - ECS native blue/green deployments, no CodeDeploy (ADR-026)
# - VPC Lattice registration for service-to-service traffic (ADR-017)
# - ADOT collector sidecar for OpenTelemetry (ADR-027)
# - Log retention on every log group (ADR-028)
# - One least-privilege task role per service (ADR-006)

data "aws_region" "current" {}

locals {
  log_group_name = "/ecs/${var.name}"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Execution role: pulls the image, writes logs and reads only this service's secrets.
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameters",
    ]
    resources = values(var.secrets)
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  count  = length(var.secrets) > 0 ? 1 : 0
  name   = "read-own-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets[0].json
}

# Task role: what the application itself may do.
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "task" {
  name   = "app"
  role   = aws_iam_role.task.id
  policy = var.task_role_policy_json
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true
      portMappings = [{
        name          = "http"
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = concat(
        [for k, v in var.environment : { name = k, value = v }],
        [{ name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" }],
      )
      secrets = [for k, v in var.secrets : { name = k, valueFrom = v }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.log_group_name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "app"
        }
      }
    },
    {
      name      = "otel-collector"
      image     = var.otel_collector_image
      essential = false
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.log_group_name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "otel"
        }
      }
    },
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name                   = var.name
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  enable_execute_command = false
  propagate_tags         = "SERVICE"

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100 - var.spot_weight
    base              = var.min_count
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.spot_weight > 0 ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = var.spot_weight
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "deployment_configuration" {
    for_each = var.blue_green == null ? [] : [var.blue_green]
    content {
      strategy             = "BLUE_GREEN"
      bake_time_in_minutes = deployment_configuration.value.bake_time_in_minutes
    }
  }

  dynamic "load_balancer" {
    for_each = var.blue_green == null ? [] : [var.blue_green]
    content {
      target_group_arn = load_balancer.value.production_target_group_arn
      container_name   = var.name
      container_port   = var.container_port

      advanced_configuration {
        alternate_target_group_arn = load_balancer.value.alternate_target_group_arn
        production_listener_rule   = load_balancer.value.production_listener_rule
        role_arn                   = load_balancer.value.infrastructure_role_arn
      }
    }
  }

  dynamic "vpc_lattice_configurations" {
    for_each = var.lattice_target_group_arn == null ? [] : [var.lattice_target_group_arn]
    content {
      target_group_arn = vpc_lattice_configurations.value
      port_name        = "http"
      role_arn         = var.lattice_infrastructure_role_arn
    }
  }

  lifecycle {
    # Autoscaling owns the task count after the first deployment.
    ignore_changes = [desired_count]
  }

  tags = var.tags
}

resource "aws_appautoscaling_target" "this" {
  service_namespace  = "ecs"
  resource_id        = "service/${element(split("/", var.cluster_arn), 1)}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_count
  max_capacity       = var.max_count
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value = var.cpu_target
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

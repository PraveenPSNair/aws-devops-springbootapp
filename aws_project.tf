#AWS Project
# Fetch latest image from ECR

data "aws_ecr_repository" "app_repo" {
  name = "my-ecr" # ECR repository name
}
data "aws_ecr_image" "latest" {
  repository_name = data.aws_ecr_repository.app_repo.name
  image_tag       = "latest"
}
# Create ECS Cluster in primary region 
resource "aws_ecs_cluster" "app_cluster" {
  name = "ecs-fargate-cluster"
}

# Create ECS Cluster in secondary region 
resource "aws_ecs_cluster" "app_cluster_secondary" {
  provider = aws.secondary
  name = "ecs-fargate-cluster"
  }

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach Policies to IAM Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# Define ECS Task Definition Primary region
resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "spring-demo-ecr"
      #image     = "${data.aws_ecr_repository.app_repo.repository_url}@${data.aws_ecr_image.latest_image.image_digest}"
      #image = "${data.aws_ecr_repository.app_repo.repository_url}:${coalesce(data.aws_ecr_image.latest.image_tag, "latest")}"
      image     = "${data.aws_ecr_repository.app_repo.repository_url}:latest"
      memory    = 512
      cpu       = 256
      essential = true
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
      }]
    }
  ])
}

# Define ECS Task Definition for secondary region
resource "aws_ecs_task_definition" "app_task_secondary" {
  provider                 = aws.secondary
  family                   = "app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "spring-demo-ecr"
      #image     = "${data.aws_ecr_repository.app_repo.repository_url}@${data.aws_ecr_image.latest_image.image_digest}"
      #image = "${data.aws_ecr_repository.app_repo.repository_url}:${coalesce(data.aws_ecr_image.latest.image_tag, "latest")}"
      image     = "${data.aws_ecr_repository.app_repo.repository_url}:latest"
      memory    = 512
      cpu       = 256
      essential = true
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
      }]
    }
  ])
}
# Create ECS Service with 1 Fargate Task
resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-063c866b07d0b3377", "subnet-0dee0a446472b0c0d"]
    security_groups  = ["sg-0040318851fdabcc5"] 
    assign_public_ip = true
  }
}
# Create ECS Service with 1 Fargate Task Secondary region 
resource "aws_ecs_service" "app_service_secondary" {
  provider        = aws.secondary
  name            = "app-service"
  cluster         = aws_ecs_cluster.app_clusterr_secondary.id
  task_definition = aws_ecs_task_definition.app_taskr_secondary.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-070459ce5f3e31ff8", "subnet-014f174517d67de25"]
    security_groups  = ["sg-0adb187c1d15241ae"] 
    assign_public_ip = true
  }
}
# CloudWatch Log Group for ECS Monitoring
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/app-service"
  retention_in_days = 7
}
# CloudWatch Log Group for ECS Monitoring
resource "aws_cloudwatch_log_group" "ecs_logs_secondary" {
  provider           = aws.secondary
  name              = "/ecs/app-service"
  retention_in_days = 7
}

# CloudWatch Alarm for ECS Task Failures
resource "aws_cloudwatch_metric_alarm" "ecs_task_failures" {
  alarm_name          = "ECS-Task-Failure-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/ECS"
  period             = "60"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "Alarm when ECS CPU utilization exceeds 80%"
  alarm_actions      = [aws_sns_topic.ecs_notifications.arn]
}
# CloudWatch Alarm for ECS Task Failures Secondary region
resource "aws_cloudwatch_metric_alarm" "ecs_task_failures_secondary" {
  provider             = aws.secondary
  alarm_name          = "ECS-Task-Failure-Alarm-Secondary"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/ECS"
  period             = "60"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "Alarm when ECS CPU utilization exceeds 80%"
  alarm_actions      = [aws_sns_topic.ecs_notifications_secondary.arn]
}

# SNS Topic for Notifications
resource "aws_sns_topic" "ecs_notifications" {
  name = "ecs-notifications"
}

# SNS Topic for Notifications
resource "aws_sns_topic" "ecs_notifications_secondary" {
  provider = aws.secondary  
  name = "ecs-notifications-secondary"
}

# Subscribe Email to SNS Topic
resource "aws_sns_topic_subscription" "ecs_email_subscription" {
  topic_arn = aws_sns_topic.ecs_notifications.arn
  protocol  = "email"
  endpoint  = "praveenps@live.com" 
}
# Subscribe Email to SNS Topic
resource "aws_sns_topic_subscription" "ecs_email_subscription_secondary" {
  provider  = aws.secondary
  topic_arn = aws_sns_topic.ecs_notifications_secondary.arn
  protocol  = "email"
  endpoint  = "praveenps@live.com" 
}

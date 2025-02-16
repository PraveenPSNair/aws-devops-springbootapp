# Fetch latest image from ECR
data "aws_ecr_repository" "app_repo" {
  name = "my-ecr" # Replace with your ECR repo name
}

# Create ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
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

# CloudWatch Log Group for ECS Logs
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/app-service"
  retention_in_days = 7
}

# Define ECS Task Definition
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
      image     = "${data.aws_ecr_repository.app_repo.repository_url}:latest"
      memory    = 512
      cpu       = 256
      essential = true
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [{ name = "REDEPLOYMENT_TRIGGER", value = "${timestamp()}" }]
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
  force_new_deployment = true # Ensures ECS deploys the latest image automatically

  network_configuration {
    subnets          = ["subnet-063c866b07d0b3377", "subnet-0dee0a446472b0c0d"]
    security_groups  = ["sg-0040318851fdabcc5"] 
    assign_public_ip = true
  }
}

# Create an S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "ecs-codepipeline-artifacts"
  acl    = "private"
}

# Create IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "CodePipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach Policies for CodePipeline
resource "aws_iam_role_policy_attachment" "codepipeline_permissions" {
  name       = "CodePipelinePermissions"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess"
}

# AWS CodePipeline for Automatic ECS Deployment
resource "aws_codepipeline" "ecs_pipeline" {
  name     = "ecs-deployment-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "ECR_Source"
      category         = "Source"
      owner           = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        RepositoryName = data.aws_ecr_repository.app_repo.name
        ImageTag       = "latest"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name             = "ECS_Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]

      configuration = {
        ClusterName = aws_ecs_cluster.app_cluster.name
        ServiceName = aws_ecs_service.app_service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

# CloudWatch Alarm for ECS Task Failures
resource "aws_cloudwatch_metric_alarm" "ecs_task_failures" {
  alarm_name          = "ECS-Task-Failure-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alarm when ECS CPU utilization exceeds 80%"
  alarm_actions      = [aws_sns_topic.ecs_notifications.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.app_cluster.name
    ServiceName = aws_ecs_service.app_service.name
  }
}

# SNS Topic for Notifications
resource "aws_sns_topic" "ecs_notifications" {
  name = "ecs-notifications"
}

# Subscribe Email to SNS Topic
resource "aws_sns_topic_subscription" "ecs_email_subscription" {
  topic_arn = aws_sns_topic.ecs_notifications.arn
  protocol  = "email"
  endpoint  = "praveenps@live.com" 
}

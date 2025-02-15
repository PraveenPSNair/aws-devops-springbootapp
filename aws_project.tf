#AWS Project
/*
resource "aws_s3_bucket" "artifact_bucket" {
  provider = aws.primary
  bucket   = "my-app-artifact-bucket"
}

resource "aws_s3_bucket" "artifact_bucket_secondary" {
  provider = aws.secondary
  bucket   = "my-app-artifact-bucket-secondary"
}
*/

# Fetch latest image from ECR

data "aws_ecr_repository" "app_repo" {
  name = "my-ecr" # Replace with your repo name
}
data "aws_ecr_image" "latest" {
  repository_name = data.aws_ecr_repository.app_repo.name
  most_recent     = true
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
      image = "${data.aws_ecr_repository.app_repo.repository_url}:${coalesce(data.aws_ecr_image.latest.image_tag, "latest")}"
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

# CloudWatch Log Group for ECS Monitoring
resource "aws_cloudwatch_log_group" "ecs_logs" {
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




































/*
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "codepipeline.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
POLICY
}

resource "aws_codestarconnections_connection" "github_connection" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_codebuild_project" "my_build_project" {
  name          = "my-build-project"
  service_role  = aws_iam_role.codepipeline_role.arn
  artifacts {
    type = "S3"
    location = aws_s3_bucket.artifact_bucket.bucket
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }
  source {
    type      = "GITHUB"
    location  = "https://github.com/my-org/my-repo.git"
  }
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_service" "my_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"
}

resource "aws_ecs_task_definition" "my_task" {
  family                   = "my-task"
  container_definitions    = <<DEFINITION
[
  {
    "name": "my-container",
    "image": "${aws_ecr_repository.my_repo.repository_url}:latest",
    "memory": 512,
    "cpu": 256,
    "essential": true
  }
]
DEFINITION
}

resource "aws_codepipeline" "my_pipeline" {
  name     = "my-app-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId = "my-org/my-repo"
        BranchName       = "main"
      }
      output_artifacts = ["source_output"]
    }
  }

  stage {
    name = "Build"
    action {
      name             = "BuildAction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.my_build_project.name
      }
    }
  }

  stage {
    name = "Approval"
    action {
      name      = "ApprovalAction"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
    }
  }

  stage {
    name = "Deploy"
    action {
      name             = "DeployAction"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      input_artifacts  = ["build_output"]
      configuration = {
        ClusterName = aws_ecs_cluster.my_cluster.name
        ServiceName = aws_ecs_service.my_service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "pipeline_failure" {
  alarm_name          = "PipelineFailureAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "PipelineExecutionFailure"
  namespace           = "AWS/CodePipeline"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert for failed pipeline execution"
  alarm_actions       = [aws_sns_topic.pipeline_alerts.arn]
}

resource "aws_sns_topic" "pipeline_alerts" {
  name = "pipeline-alerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = "admin@example.com"
}
*/ 
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "flask-demo"
      Environment = "demo"
      ManagedBy   = "Terraform"
    }
  }
}


# Data sources
data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# Security Group
resource "aws_security_group" "ecs_instances" {
  name_prefix = "flask-demo-ecs-"
  description = "Security group for ECS EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "All from VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing.cidr_block]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Container ports"
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-demo-ecs-sg"
  }
}

#Application Load balancer
#resource "aws_lb" "flask" {
#  name               = "flask-demo-alb"
#  load_balancer_type = "application"
#  subnets            = data.aws_subnets.existing.ids
#  security_groups    = [aws_security_group.ecs_instances.id]
#}
#
### Target group
#resource "aws_lb_target_group" "flask" {
#  name        = "flask-demo-tg"
#  port        = 5000
#  protocol    = "HTTP"
#  vpc_id      = var.vpc_id
#  target_type = "instance"
#
#  health_check {
#    path = "/health"
#  }
#}
#
#
#### ALB Listener Rule for the TG
#resource "aws_lb_listener" "http" {
#  load_balancer_arn = aws_lb.flask.arn
#  port              = 80
#  protocol          = "HTTP"
#
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.flask.arn
#  }
#}


# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "flask-demo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/flask-demo"
  retention_in_days = 1
}

# IAM Role for EC2
resource "aws_iam_role" "ecs_instance_role" {
  name = "flask-demo-ecs-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "flask-demo-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# IAM Role for Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "flask-demo-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "flask-demo-cluster"
}

# Launch Template
resource "aws_launch_template" "ecs" {
  name_prefix   = "flask-demo-ecs-"
  image_id      = data.aws_ami.ecs_ami.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "flask-demo-ecs-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name_prefix         = "flask-demo-ecs-asg-"
  vpc_zone_identifier = data.aws_subnets.existing.ids
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "flask-demo-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}

# Capacity Provider
resource "aws_ecs_capacity_provider" "main" {
  name = "flask-demo-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
    base              = 1
  }
}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "flask-demo"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "flask-app"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    memory    = 256
    cpu       = 128

    portMappings = [{
      containerPort = 5000
      hostPort      = 0
      protocol      = "tcp"
    }]

    environment = [{
      name  = "ENVIRONMENT"
      value = "demo"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "flask-demo-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "EC2"
  
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [
    aws_autoscaling_group.ecs,
    aws_ecs_cluster_capacity_providers.main
  ]
}


#resource "aws_ecs_service" "app" {
#  name            = "flask-demo-service"
#  cluster         = aws_ecs_cluster.main.id
#  task_definition = aws_ecs_task_definition.app.arn
#  desired_count   = 1
#  launch_type     = "EC2"
#
#  load_balancer {
#    target_group_arn = aws_lb_target_group.flask.arn
#    container_name   = "flask-app"
#    container_port   = 5000
#  }
#
#  deployment_minimum_healthy_percent = 0
#  deployment_maximum_percent         = 100
#
#  depends_on = [
#    aws_lb_listener.http,
#    aws_autoscaling_group.ecs
#  ]
#}


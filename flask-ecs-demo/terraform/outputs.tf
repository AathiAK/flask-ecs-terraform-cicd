output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "instance_public_ips" {
  description = "Command to get EC2 instance public IPs"
  value       = "aws ec2 describe-instances --filters 'Name=tag:Name,Values=flask-demo-ecs-instance' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].PublicIpAddress' --output text"
}

output "account_id" {
  description = "The AWS account ID the provider is authenticated against."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "The AWS region resources are deployed into."
  value       = data.aws_region.current.name
}

output "ecr_repository_url" {
  description = "ECR repository URL to tag/push images to. Set as GitHub var ECR_REPOSITORY."
  value       = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN GitHub Actions assumes via OIDC. Set as GitHub var AWS_ROLE_ARN."
  value       = aws_iam_role.github_actions.arn
}

output "ec2_instance_id" {
  description = "EC2 instance ID. Set as GitHub var EC2_INSTANCE_ID."
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "URL the Hello World server is reachable at once deployed."
  value       = "http://${aws_instance.app.public_ip}:${var.host_port}"
}

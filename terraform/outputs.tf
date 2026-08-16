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

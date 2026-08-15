output "account_id" {
  description = "The AWS account ID the provider is authenticated against."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "The AWS region resources are deployed into."
  value       = data.aws_region.current.name
}

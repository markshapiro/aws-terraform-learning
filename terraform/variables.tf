variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use for credentials. Leave null to use the default credential chain (env vars, default profile, IAM role)."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project identifier, applied as a default tag to all resources."
  type        = string
  default     = "aws-terraform-learning"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

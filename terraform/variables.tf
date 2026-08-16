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

variable "ecr_repository_name" {
  description = "Name of the ECR repository the GitHub Actions workflow pushes to."
  type        = string
  default     = "hello-world"
}

variable "github_owner" {
  description = "GitHub org/user that owns the repository."
  type        = string
  default     = "markshapiro"
}

variable "github_repo" {
  description = "GitHub repository name (without the owner)."
  type        = string
  default     = "aws-terraform-learning"
}

variable "github_oidc_subjects" {
  description = <<-EOT
    List of GitHub OIDC 'sub' claims allowed to assume the CI role. Defaults to
    pushes on the main branch. Add entries like
    "repo:<owner>/<repo>:ref:refs/tags/*" or
    "repo:<owner>/<repo>:environment:prod" to widen access.
  EOT
  type        = list(string)
  default     = null
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider. Set to false if one already exists in the account (only one per account is allowed)."
  type        = bool
  default     = true
}

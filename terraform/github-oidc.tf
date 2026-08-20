# GitHub Actions authenticates to AWS via OpenID Connect (OIDC) — no long-lived
# access keys stored in the repo. GitHub presents a short-lived token; AWS trusts
# it and hands back temporary credentials scoped to the role below.

locals {
  github_repository = "${var.github_owner}/${var.github_repo}"

  # Refs allowed to assume the role. Defaults to the main branch.
  github_allowed_refs = coalesce(var.github_allowed_refs, ["refs/heads/main"])

  # AWS requires the trust policy to constrain `sub` (or `job_workflow_ref`).
  # With "immutable subject claims" enabled, `sub` looks like
  #   repo:owner@<owner_id>/repo@<repo_id>:ref:refs/heads/main
  # so we wildcard the numeric IDs and pin owner, repo, and ref.
  github_sub_patterns = [
    for r in local.github_allowed_refs :
    "repo:${var.github_owner}@*/${var.github_repo}@*:ref:${r}"
  ]

  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# Create the provider, OR look it up if it already exists in the account.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# Trust policy: only the GitHub OIDC provider, scoped to our repo + allowed refs.
#
# AWS mandates a constraint on `sub` (or `job_workflow_ref`), so we match `sub`
# with the numeric owner/repo IDs wildcarded (see local.github_sub_patterns).
# The extra `repository` StringEquals pins the exact human-readable repo name.
data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository"
      values   = [local.github_repository]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_sub_patterns
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  description        = "Assumed by GitHub Actions via OIDC to push images to ECR."
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

# Least-privilege ECR push permissions, scoped to this one repository
# (GetAuthorizationToken has no resource scope, so it stays on "*").
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "GetAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

# Lets the deploy job trigger a redeploy on the EC2 instance via SSM Run Command.
data "aws_iam_policy_document" "deploy_ssm" {
  statement {
    sid     = "SendCommand"
    effect  = "Allow"
    actions = ["ssm:SendCommand"]
    resources = [
      aws_instance.app.arn,
      "arn:aws:ssm:${data.aws_region.current.name}::document/AWS-RunShellScript",
    ]
  }

  statement {
    sid    = "ReadCommandResult"
    effect = "Allow"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy_ssm" {
  name   = "deploy-ssm"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deploy_ssm.json
}

# -----------------------------------------------------------------------------
# Networking: use the account's default VPC + subnets to keep the demo simple.
# -----------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI (Docker + AWS CLI + SSM agent available).
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------------------------------------------------------
# Security group: allow the app port in from the internet, everything out.
# No SSH (port 22) — we reach the box through SSM instead.
# -----------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app"
  description = "Allow inbound app traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "App HTTP"
    from_port   = var.host_port
    to_port     = var.host_port
    protocol    = "tcp"
    cidr_blocks = var.app_ingress_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------------------------------------------
# Instance IAM role: pull from ECR + be managed by SSM (no SSH keys needed).
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Lets AWS Systems Manager manage the instance (Session Manager, Run Command).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read-only ECR pull permissions, scoped to our repository.
data "aws_iam_policy_document" "ecr_pull" {
  statement {
    sid       = "GetAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "Pull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name   = "ecr-pull"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ecr_pull.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2"
  role = aws_iam_role.ec2.name
}

# -----------------------------------------------------------------------------
# The instance itself.
# -----------------------------------------------------------------------------
locals {
  deploy_script = templatefile("${path.module}/templates/deploy-app.sh.tftpl", {
    region         = var.aws_region
    registry       = split("/", aws_ecr_repository.app.repository_url)[0]
    image          = "${aws_ecr_repository.app.repository_url}:latest"
    container_name = var.project_name
    host_port      = var.host_port
    container_port = var.container_port
  })

  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    deploy_script = local.deploy_script
  })
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-app"
  }
}

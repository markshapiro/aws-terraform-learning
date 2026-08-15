terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # For learning, state is kept locally by default. When you're ready for a
  # shared/remote backend (e.g. S3 + DynamoDB lock table), configure it here.
  # backend "s3" {
  #   bucket         = "my-tfstate-bucket"
  #   key            = "aws-terraform-learning/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

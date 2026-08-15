# Resources go here.
#
# `aws_caller_identity` is a harmless data source that confirms your provider
# credentials work — run `terraform plan` and it will show your account ID with
# nothing to create. Replace it with real resources as you learn.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

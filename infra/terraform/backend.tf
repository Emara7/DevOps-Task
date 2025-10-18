terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Use local backend by default; switch to S3+DynamoDB in real deployments
  backend "local" {}
}

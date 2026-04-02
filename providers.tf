terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket                     = "chinmayto-terraform-state-bucket-1755526674"
    key                        = "terraform-ci-cd/terraform.tfstate"
    region                     = "us-east-1"
    encrypt                    = true
    use_lockfile               = true
    skip_requesting_account_id = false
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

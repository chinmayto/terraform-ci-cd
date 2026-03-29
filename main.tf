terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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

module "lambda" {
  source = "./modules/lambda"

  environment        = var.environment
  memory_size        = var.lambda_memory_size
  timeout            = var.lambda_timeout
  log_retention_days = var.log_retention_days
}

module "api_gateway" {
  source = "./modules/api_gateway"

  environment          = var.environment
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
}

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

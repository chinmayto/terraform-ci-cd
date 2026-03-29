output "website_url" {
  description = "Public URL of the website"
  value       = module.api_gateway.invoke_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = module.api_gateway.api_id
}

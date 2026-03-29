output "invoke_arn" {
  value = aws_lambda_function.website.invoke_arn
}

output "function_name" {
  value = aws_lambda_function.website.function_name
}

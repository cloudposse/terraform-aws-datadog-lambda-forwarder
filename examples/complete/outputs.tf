output "lambda_forwarder_log_function_arn" {
  description = "Datadog Lambda forwarder CloudWatch/S3 function ARN"
  value       = module.datadog_lambda_forwarder.lambda_forwarder_log_function_arn
}

output "lambda_forwarder_log_function_name" {
  description = "Datadog Lambda forwarder CloudWatch/S3 function name"
  value       = module.datadog_lambda_forwarder.lambda_forwarder_log_function_name
}

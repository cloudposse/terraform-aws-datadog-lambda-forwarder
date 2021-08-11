output "lambda_forwarder_log_function_arn" {
  description = "Datadog Lambda forwarder for Enhanced RDS Metrics function ARN"
  value       = module.datadog_lambda_forwarder.lambda_forwarder_log_function_arn
}

output "lambda_forwarder_log_function_name" {
  description = "Datadog Lambda forwarder for Enhanced RDS Metrics function ARN"
  value       = module.datadog_lambda_forwarder.lambda_forwarder_log_function_name
}

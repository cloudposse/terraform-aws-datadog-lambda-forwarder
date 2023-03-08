output "lambda_forwarder_rds_function_arn" {
  description = "Datadog Lambda forwarder RDS Enhanced Monitoring function ARN"
  value       = local.lambda_enabled && var.forwarder_rds_enabled ? join("", aws_lambda_function.forwarder_rds[*].arn) : null
}

output "lambda_forwarder_rds_enhanced_monitoring_function_name" {
  description = "Datadog Lambda forwarder RDS Enhanced Monitoring function name"
  value       = local.lambda_enabled && var.forwarder_rds_enabled ? join("", aws_lambda_function.forwarder_rds[*].function_name) : null
}

output "lambda_forwarder_log_function_arn" {
  description = "Datadog Lambda forwarder CloudWatch/S3 function ARN"
  value       = local.lambda_enabled && var.forwarder_log_enabled ? join("", aws_lambda_function.forwarder_log[*].arn) : null
}

output "lambda_forwarder_log_function_name" {
  description = "Datadog Lambda forwarder CloudWatch/S3 function name"
  value       = local.lambda_enabled && var.forwarder_log_enabled ? join("", aws_lambda_function.forwarder_log[*].function_name) : null
}

output "lambda_forwarder_vpc_log_function_arn" {
  description = "Datadog Lambda forwarder VPC Flow Logs function ARN"
  value       = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? join("", aws_lambda_function.forwarder_vpclogs[*].arn) : null
}

output "lambda_forwarder_vpc_log_function_name" {
  description = "Datadog Lambda forwarder VPC Flow Logs function name"
  value       = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? join("", aws_lambda_function.forwarder_vpclogs[*].function_name) : null
}

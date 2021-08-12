
output "lambda_forwarder_rds_function_arn" {
  description = "Datadog Lambda forwarder Enhanced RDS Metrics function ARN"
  value       = var.forwarder_rds_enabled ? join("", aws_lambda_function.forwarder_rds.*.arn) : ""
}

output "lambda_forwarder_rds_enhanced_monitoring_function_name" {
  description = "Datadog Lambda forwarder Enhanced RDS Metrics function name"
  value       = var.forwarder_rds_enabled ? join("", aws_lambda_function.forwarder_rds.*.function_name) : ""
}

output "lambda_forwarder_log_function_arn" {
  description = "Datadog Lambda forwarder CloudWatch/S3 function ARN"
  value       = join("", aws_lambda_function.forwarder_log.*.arn)
}

output "lambda_forwarder_log_function_name" {
  description = "Datadog Lambda forwarder CloudWatch/S3 function name"
  value       = join("", aws_lambda_function.forwarder_log.*.function_name)
}

output "lambda_forwarder_vpc_log_function_arn" {
  description = "Datadog Lambda forwarder VPC FlowLogs function ARN"
  value       = join("", aws_lambda_function.forwarder_vpclogs.*.arn)
}

output "lambda_forwarder_vpc_log_function_name" {
  description = "Datadog Lambda forwarder VPC FlowLogs function name"
  value       = join("", aws_lambda_function.forwarder_vpclogs.*.function_name)
}

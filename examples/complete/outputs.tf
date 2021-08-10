output "lambda_forwarder_rds_enhanced_monitoring_arn" {
  description = "Datadog Lambda forwarder for Enhanced RDS Metrics function ARN"
  value       = module.datadog_lambda_forwarder.lambda_forwarder_rds_enhanced_monitoring_arn
}


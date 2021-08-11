# output "id" {
#   description = "ID of the created example"
#   value       = module.this.enabled ? module.this.id : null
# }

# output "example" {
#   description = "Example output"
#   value       = module.this.enabled ? local.example : null
# }

# output "random" {
#   description = "Stable random number for this example"
#   value       = module.this.enabled ? join("", random_integer.example[*].result) : null
# }


output "lambda_forwarder_rds_enhanced_monitoring_arn" {
  description = "Datadog Lambda forwarder for Enhanced RDS Metrics function ARN"
  value       = var.forwarder_rds_enabled ? join("", aws_lambda_function.forwarder_rds[0].arn) : ""
}

output "lambda_forwarder_rds_enhanced_monitoring_function_name" {
  description = "Datadog Lambda forwarder for Enhanced RDS Metrics function ARN"
  value       = var.forwarder_rds_enabled ? join("", aws_lambda_function.forwarder_rds[0].function_name) : ""
}

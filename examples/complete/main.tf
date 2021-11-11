module "cloudwatch_logs" {
  source  = "cloudposse/cloudwatch-logs/aws"
  version = "0.5.0"

  name    = "postgresql"
  context = module.this.context
}

resource "aws_ssm_parameter" "datadog_key" {
  name        = "/datadog/datadog_api_key"
  description = "Test Datadog key"
  type        = "SecureString"
  value       = "testkey"
}

module "datadog_lambda_log_forwarder" {
  source = "../.."

  forwarder_log_enabled = true

  cloudwatch_forwarder_log_groups = {
    postgres = {
      name           = module.cloudwatch_logs.log_group_name
      filter_pattern = ""
    }
  }

  dd_api_key_source = var.dd_api_key_source

  context = module.this.context

  depends_on = [aws_ssm_parameter.datadog_key]
}

module "cloudwatch-logs" {
  source  = "cloudposse/cloudwatch-logs/aws"
  version = "0.4.3"
  name    = "postgresql"
  context = module.this.context
}

resource "aws_ssm_parameter" "datadog_key" {
  name        = "/datadog/api-key"
  description = "Test Datadog key"
  type        = "SecureString"
  value       = "testkey"
}

module "datadog_lambda_forwarder" {
  source                = "../.."
  forwarder_log_enabled = true
  cloudwatch_forwarder_log_groups = {
    postgres = module.cloudwatch-logs.log_group_name
  }
  dd_api_key_source = var.dd_api_key_source

  context    = module.this.context
  depends_on = [aws_ssm_parameter.datadog_key]
}

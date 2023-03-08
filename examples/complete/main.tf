module "cloudwatch_logs" {
  source  = "cloudposse/cloudwatch-logs/aws"
  version = "0.6.1"

  name    = "postgresql"
  context = module.this.context
}

resource "aws_ssm_parameter" "datadog_key" {
  count = module.this.enabled ? 1 : 0

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

  cloudwatch_forwarder_event_patterns = var.cloudwatch_forwarder_event_patterns

  # Supply tags
  # This results in DD_TAGS = "testkey10,testkey3:testval3,testkey4:testval4"
  dd_tags_map = {
    testkey3  = "testval3"
    testkey4  = "testval4"
    testkey10 = null
  }

  dd_api_key_source = var.dd_api_key_source

  context = module.this.context

  depends_on = [aws_ssm_parameter.datadog_key]
}

# The Datadog lambda forwarder is an entirely different code whithing the same repo and without a release
# https://github.com/DataDog/datadog-serverless-functions/blob/master/aws/vpc_flow_log_monitoring/lambda_function.py
# This code can only read VPC flog logs sent to a Cloudwatch Log Group ( not from S3 )
module "forwarder_vpclogs_label" {
  count      = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0
  source     = "cloudposse/label/null"
  version    = "0.24.1" # requires Terraform >= 0.13.0
  attributes = ["forwarder-vpclogs"]

  context = module.this.context
}

module "forwarder_vpclogs_artifact" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  source      = "cloudposse/module-artifact/external"
  version     = "0.7.0"
  filename    = "lambda_function.py"
  module_name = var.dd_module_name
  module_path = path.module
  url         = "https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/master/aws/vpc_flow_log_monitoring/lambda_function.py?ref=${var.dd_forwarder_version}"
}

data "archive_file" "forwarder_vpclogs" {
  count       = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0
  type        = "zip"
  source_file = module.forwarder_vpclogs.file
  output_path = "${path.module}/lambda.zip"
}

######################################################################
## Create lambda function

resource "aws_lambda_function" "forwarder_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  #checkov:skip=BC_AWS_GENERAL_64: (Pertaining to Lambda DLQ) Vendor lambda does not have a means to reprocess failed events.

  description                    = "Datadog forwarder for VPC Flow"
  filename                       = data.archive_file.forwarder_vpclogs[0].output_path
  function_name                  = module.forwarder_vpclogs_label.id
  role                           = aws_iam_role.lambda[0].arn
  handler                        = "lambda_function.lambda_handler"
  source_code_hash               = data.archive_file.forwarder_vpclogs[0].output_base64sha256
  runtime                        = var.lambda_runtime
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions
  tags                           = module.forwarder_vpclogs_label[0].tags


  dynamic "vpc_config" {
    for_each = try(length(var.subnet_ids), 0) > 0 && try(length(var.security_group_ids), 0) > 0 ? [true] : []
    content {
      security_group_ids = var.security_group_ids
      subnet_ids         = var.subnet_ids
    }
  }

  environment {
    variables = local.lambda_env
  }

  tracing_config {
    mode = var.tracing_config_mode
  }
}

resource "aws_lambda_permission" "cloudwatch_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  statement_id  = "datadog-forwarder-flowlogs-cloudwatchlogspermission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_vpclogs[0].function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:${var.vpclogs_cloudwatch_log_group}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "datadog_log_subscription_filter_vpclogs" {
  count           = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0
  name            = module.forwarder_vpclogs_label[0].id
  log_group_name  = var.vpclogs_cloudwatch_log_group
  destination_arn = aws_lambda_function.forwarder_vpclogs[0].arn
  filter_pattern  = ""
}


resource "aws_cloudwatch_log_group" "forwarder_vpclogs" {

  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.forwarder_vpclogs[0].function_name}"
  retention_in_days = var.forwarder_log_retention_days

  kms_key_id = var.kms_key_id

  tags = module.forwarder_vpclogs_label[0].tags
}

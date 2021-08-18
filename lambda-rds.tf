# The Datadog lambda forwarder is an entirely different code whithing the same repo and without a release, the code is here:
# https://github.com/DataDog/datadog-serverless-functions/blob/master/aws/rds_enhanced_monitoring/lambda_function.py
# This code can only read RDS Enhanced monitoring metrics from cloudwatch and nothing else.
# if you'd like to read the Auth log from an Aurora cluster, you need to use the lambda-log and pass the Cloudwatch group of the cluster/clusters

locals {
  forwarder_rds_artifact_url = var.forwarder_rds_artifact_url != null ? var.forwarder_rds_artifact_url : "https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/master/aws/rds_enhanced_monitoring/lambda_function.py?ref=${var.dd_forwarder_version}"
}
module "forwarder_rds_label" {
  count      = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0
  source     = "cloudposse/label/null"
  version    = "0.24.1" # requires Terraform >= 0.13.0
  attributes = ["forwarder-rds"]

  context = module.this.context
}

module "forwarder_rds_artifact" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  source      = "cloudposse/module-artifact/external"
  version     = "0.7.0"
  filename    = "forwarder-rds.py"
  module_name = var.dd_module_name
  module_path = path.module
  url         = local.forwarder_rds_artifact_url
}

data "archive_file" "forwarder_rds" {
  count       = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0
  type        = "zip"
  source_file = module.forwarder_rds_artifact[0].file
  output_path = "${path.module}/lambda.zip"
}

######################################################################
## Create lambda function

resource "aws_lambda_function" "forwarder_rds" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  #checkov:skip=BC_AWS_GENERAL_64: (Pertaining to Lambda DLQ) Vendor lambda does not have a means to reprocess failed events.

  description                    = "Datadog forwarder for RDS enhanced monitoring."
  filename                       = data.archive_file.forwarder_rds[0].output_path
  function_name                  = module.forwarder_rds_label[0].id
  role                           = aws_iam_role.lambda[0].arn
  handler                        = "forwarder-rds.lambda_handler"
  source_code_hash               = data.archive_file.forwarder_rds[0].output_base64sha256
  runtime                        = var.lambda_runtime
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions
  tags                           = module.forwarder_rds_label[0].tags

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

resource "aws_lambda_permission" "cloudwatch_enhance_rds" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  statement_id  = "datadog-forwarder-rds-cloudwatch-logs-permission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_rds[0].function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:RDSOSMetrics:*"
}

resource "aws_cloudwatch_log_subscription_filter" "datadog_log_subscription_filter_rds" {
  count           = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0
  name            = module.forwarder_rds_label[0].id
  log_group_name  = "RDSOSMetrics"
  destination_arn = aws_lambda_function.forwarder_rds[0].arn
  filter_pattern  = ""
}

resource "aws_cloudwatch_log_group" "forwarder_rds" {

  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.forwarder_rds[0].function_name}"
  retention_in_days = var.forwarder_log_retention_days

  kms_key_id = var.kms_key_id

  tags = module.forwarder_rds_label[0].tags
}

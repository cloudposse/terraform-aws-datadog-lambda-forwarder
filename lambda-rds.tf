# The Datadog Lambda RDS enhanced monitoring code:
# https://github.com/DataDog/datadog-serverless-functions/blob/master/aws/rds_enhanced_monitoring/lambda_function.py
# This code can only read RDS Enhanced monitoring metrics from CloudWatch and nothing else.
# If you'd like to read the Auth log from an Aurora cluster, you need to use the `lambda-log` Lambda function and pass the CloudWatch Group of the cluster/clusters

locals {
  forwarder_rds_artifact_url = var.forwarder_rds_artifact_url != null ? var.forwarder_rds_artifact_url : (
    "https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/master/aws/rds_enhanced_monitoring/lambda_function.py?ref=${var.dd_forwarder_version}"
  )
}

module "forwarder_rds_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.lambda_enabled && var.forwarder_rds_enabled

  attributes = ["rds"]

  context = module.this.context
}

module "forwarder_rds_artifact" {
  count   = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0
  source  = "cloudposse/module-artifact/external"
  version = "0.7.2"

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

resource "aws_iam_role" "lambda_forwarder_rds" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  name = module.forwarder_rds_label.id

  path                 = var.forwarder_iam_path
  description          = "Datadog Lambda RDS enhanced monitoring forwarder"
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  permissions_boundary = var.rds_permissions_boundary
  tags                 = module.forwarder_rds_label.tags
}

resource "aws_iam_policy" "lambda_forwarder_rds" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  name        = module.forwarder_rds_label.id
  path        = var.forwarder_iam_path
  description = "Datadog Lambda RDS enhanced monitoring forwarder"
  policy      = data.aws_iam_policy_document.lambda_default[0].json
  tags        = module.forwarder_rds_label.tags
}

resource "aws_iam_role_policy_attachment" "lambda_forwarder_rds" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  role       = aws_iam_role.lambda_forwarder_rds[0].name
  policy_arn = aws_iam_policy.lambda_forwarder_rds[0].arn
}

######################################################################
## Create lambda function

resource "aws_lambda_function" "forwarder_rds" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  #checkov:skip=BC_AWS_GENERAL_64: (Pertaining to Lambda DLQ) Vendor lambda does not have a means to reprocess failed events.

  description                    = "Datadog forwarder for RDS enhanced monitoring"
  filename                       = data.archive_file.forwarder_rds[0].output_path
  function_name                  = module.forwarder_rds_label.id
  role                           = aws_iam_role.lambda_forwarder_rds[0].arn
  handler                        = "forwarder-rds.lambda_handler"
  source_code_hash               = data.archive_file.forwarder_rds[0].output_base64sha256
  runtime                        = var.lambda_runtime
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions
  layers                         = var.forwarder_rds_layers

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

  tags = module.forwarder_rds_label.tags
}

resource "aws_lambda_permission" "cloudwatch_enhanced_rds_monitoring" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  statement_id  = "datadog-forwarder-rds-cloudwatch-logs-permission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_rds[0].function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${local.arn_format}:logs:${local.aws_region}:${local.aws_account_id}:log-group:RDSOSMetrics:*"
}

resource "aws_cloudwatch_log_subscription_filter" "datadog_log_subscription_filter_rds" {
  count           = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0
  name            = module.forwarder_rds_label.id
  log_group_name  = "RDSOSMetrics"
  destination_arn = aws_lambda_function.forwarder_rds[0].arn
  filter_pattern  = var.forwarder_rds_filter_pattern
}

resource "aws_cloudwatch_log_group" "forwarder_rds" {
  count = local.lambda_enabled && var.forwarder_rds_enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.forwarder_rds[0].function_name}"
  retention_in_days = var.forwarder_log_retention_days
  kms_key_id        = var.kms_key_id

  tags = module.forwarder_rds_label.tags
}

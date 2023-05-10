# The Datadog Lambda forwarder for VPC flow logs code:
# https://github.com/DataDog/datadog-serverless-functions/blob/master/aws/vpc_flow_log_monitoring/lambda_function.py
# This code can only read VPC flow logs sent to a CloudWatch Log Group ( not from S3 )

locals {
  forwarder_vpc_logs_artifact_url = var.forwarder_vpc_logs_artifact_url != null ? var.forwarder_vpc_logs_artifact_url : (
    "https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/master/aws/vpc_flow_log_monitoring/lambda_function.py?ref=${var.dd_forwarder_version}"
  )
}

module "forwarder_vpclogs_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.lambda_enabled && var.forwarder_vpc_logs_enabled

  attributes = ["vpc-flow-logs"]

  context = module.this.context
}

module "forwarder_vpclogs_artifact" {
  count   = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0
  source  = "cloudposse/module-artifact/external"
  version = "0.7.2"

  filename    = "lambda_function.py"
  module_name = var.dd_module_name
  module_path = path.module
  url         = local.forwarder_vpc_logs_artifact_url
}

data "archive_file" "forwarder_vpclogs" {
  count       = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0
  type        = "zip"
  source_file = module.forwarder_vpclogs_artifact[0].file
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_forwarder_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  name = module.forwarder_vpclogs_label.id

  path                 = var.forwarder_iam_path
  description          = "Datadog Lambda VPC Flow Logs forwarder"
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  permissions_boundary = var.vpc_logs_permissions_boundary
  tags                 = module.forwarder_vpclogs_label.tags
}

resource "aws_iam_policy" "lambda_forwarder_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  name        = module.forwarder_vpclogs_label.id
  path        = var.forwarder_iam_path
  description = "Datadog Lambda VPC Flow Logs forwarder"
  policy      = data.aws_iam_policy_document.lambda_default[0].json
  tags        = module.forwarder_vpclogs_label.tags
}

resource "aws_iam_role_policy_attachment" "lambda_forwarder_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  role       = aws_iam_role.lambda_forwarder_vpclogs[0].name
  policy_arn = aws_iam_policy.lambda_forwarder_vpclogs[0].arn
}

######################################################################
## Create lambda function

resource "aws_lambda_function" "forwarder_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  #checkov:skip=BC_AWS_GENERAL_64: (Pertaining to Lambda DLQ) Vendor lambda does not have a means to reprocess failed events.

  description                    = "Datadog Lambda forwarder for VPC Flow Logs"
  filename                       = data.archive_file.forwarder_vpclogs[0].output_path
  function_name                  = module.forwarder_vpclogs_label.id
  role                           = aws_iam_role.lambda_forwarder_vpclogs[0].arn
  handler                        = "lambda_function.lambda_handler"
  source_code_hash               = data.archive_file.forwarder_vpclogs[0].output_base64sha256
  runtime                        = var.lambda_runtime
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions
  layers                         = var.forwarder_vpc_logs_layers

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



  tags = module.forwarder_vpclogs_label.tags
}

resource "aws_lambda_permission" "cloudwatch_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  statement_id  = "datadog-forwarder-flowlogs-cloudwatchlogs-permission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_vpclogs[0].function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${local.arn_format}:logs:${local.aws_region}:${local.aws_account_id}:log-group:${var.vpclogs_cloudwatch_log_group}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "datadog_log_subscription_filter_vpclogs" {
  count           = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0
  name            = module.forwarder_vpclogs_label.id
  log_group_name  = var.vpclogs_cloudwatch_log_group
  destination_arn = aws_lambda_function.forwarder_vpclogs[0].arn
  filter_pattern  = var.forwarder_vpclogs_filter_pattern
}

resource "aws_cloudwatch_log_group" "forwarder_vpclogs" {
  count = local.lambda_enabled && var.forwarder_vpc_logs_enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.forwarder_vpclogs[0].function_name}"
  retention_in_days = var.forwarder_log_retention_days
  kms_key_id        = var.kms_key_id

  tags = module.forwarder_vpclogs_label.tags
}

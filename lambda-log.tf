# The principal Lambda forwarder for DD that is implemented here
# https://github.com/DataDog/datadog-serverless-functions/blob/master/aws/logs_monitoring/lambda_function.py
# can scrape logs from S3 from specific services (not all s3 logs are supported)
# Refer to the table here https://docs.datadoghq.com/logs/guide/send-aws-services-logs-with-the-datadog-lambda-function/?tab=awsconsole#automatically-set-up-triggers
locals {
  s3_logs_enabled            = local.lambda_enabled && var.s3_buckets != null && var.forwarder_log_enabled ? true : false
  forwarder_log_artifact_url = var.forwarder_log_artifact_url != "" ? var.forwarder_log_artifact_url : "https://github.com/DataDog/datadog-serverless-functions/releases/download/aws-dd-forwarder-${var.dd_forwarder_version}/aws-dd-forwarder-${var.dd_forwarder_version}.zip"
}

module "forwarder_log_label" {
  count      = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0
  source     = "cloudposse/label/null"
  version    = "0.24.1" # requires Terraform >= 0.13.0
  attributes = ["forwarder-log"]

  context = module.this.context
}

module "forwarder_log_artifact" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  source      = "cloudposse/module-artifact/external"
  version     = "0.7.0"
  filename    = "forwarder-log.zip"
  module_name = var.dd_module_name
  module_path = path.module
  url         = local.forwarder_log_artifact_url
}

######################################################################
## Create lambda function

resource "aws_lambda_function" "forwarder_log" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  #checkov:skip=BC_AWS_GENERAL_64: (Pertaining to Lambda DLQ) Vendor lambda does not have a means to reprocess failed events.

  description                    = "Datadog forwarder for log forwarding."
  filename                       = module.forwarder_log_artifact[0].file
  function_name                  = module.forwarder_log_label[0].id
  role                           = aws_iam_role.lambda[0].arn
  handler                        = "lambda_function.lambda_handler"
  source_code_hash               = module.forwarder_log_artifact[0].base64sha256
  runtime                        = var.lambda_runtime
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions
  tags                           = module.forwarder_log_label[0].tags

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

resource "aws_lambda_permission" "allow_s3_bucket" {
  for_each      = local.s3_logs_enabled ? toset(var.s3_buckets) : []
  statement_id  = "AllowS3ToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_log[0].arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${each.value}"
}

resource "aws_s3_bucket_notification" "s3_bucket_notification" {
  for_each = local.s3_logs_enabled ? toset(var.s3_buckets) : []
  bucket   = each.key

  lambda_function {
    lambda_function_arn = aws_lambda_function.forwarder_log[0].arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_bucket]
}

data "aws_iam_policy_document" "s3_log_bucket" {
  count = local.s3_logs_enabled ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListObjects",
    ]
    resources = concat(formatlist("arn:aws:s3:::%s", var.s3_buckets), formatlist("arn:aws:s3:::%s/*", var.s3_buckets))
  }

  dynamic "statement" {
    for_each = try(length(var.s3_bucket_kms_arns), 0) > 0 ? [true] : []
    content {
      effect = "Allow"

      actions = [
        "kms:Decrypt"
      ]
      resources = var.s3_bucket_kms_arns
    }
  }
}

resource "aws_iam_policy" "datadog_s3" {
  count       = local.s3_logs_enabled ? 1 : 0
  name        = module.forwarder_log_label[0].id
  description = "Policy for Datadog S3 integration"
  policy      = join("", data.aws_iam_policy_document.s3_log_bucket.*.json)
}

resource "aws_iam_role_policy_attachment" "datadog_s3" {
  count      = local.s3_logs_enabled ? 1 : 0
  role       = join("", aws_iam_role.lambda.*.name)
  policy_arn = join("", aws_iam_policy.datadog_s3.*.arn)
}

# Lambda Forwarder logs
resource "aws_cloudwatch_log_group" "forwarder_log" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.forwarder_log[0].function_name}"
  retention_in_days = var.forwarder_log_retention_days

  kms_key_id = var.kms_key_id

  tags = module.forwarder_log_label[0].tags
}

# Cloudwatch Log Groups
resource "aws_lambda_permission" "cloudwatch_groups" {
  for_each = local.lambda_enabled && var.forwarder_log_enabled ? var.cloudwatch_forwarder_log_groups : {}

  statement_id  = "datadog-forwarder-${each.key}-permission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_log[0].function_name
  principal     = "logs.${local.aws_region}.amazonaws.com"
  source_arn    = "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:${each.value}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "cloudwatch_log_subscription_filter" {
  for_each        = local.lambda_enabled && var.forwarder_log_enabled ? var.cloudwatch_forwarder_log_groups : {}
  name            = module.forwarder_log_label[0].id
  log_group_name  = each.value
  destination_arn = aws_lambda_function.forwarder_log[0].arn
  filter_pattern  = ""
}

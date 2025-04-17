# The principal Lambda forwarder for Datadog is implemented here:
# https://github.com/DataDog/datadog-serverless-functions/blob/master/aws/logs_monitoring/lambda_function.py
# It can scrape logs from S3 from specific services (not all s3 logs are supported)
# Refer to the table here https://docs.datadoghq.com/logs/guide/send-aws-services-logs-with-the-datadog-lambda-function/?tab=awsconsole#automatically-set-up-triggers

locals {
  s3_bucket_names_to_authorize = toset(flatten([var.s3_buckets, [for o in var.s3_buckets_with_prefixes : o.bucket_name]]))
  s3_logs_enabled              = local.lambda_enabled && var.forwarder_log_enabled && (length(var.s3_buckets) != 0 || length(var.s3_buckets_with_prefixes) != 0)

  forwarder_log_artifact_url = var.forwarder_log_artifact_url != null ? var.forwarder_log_artifact_url : (
    "https://github.com/DataDog/datadog-serverless-functions/releases/download/aws-dd-forwarder-${var.dd_forwarder_version}/${var.dd_artifact_filename}-${var.dd_forwarder_version}.zip"
  )
}

module "forwarder_log_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.lambda_enabled && var.forwarder_log_enabled

  attributes = ["logs"]

  context = module.this.context
}

module "forwarder_log_s3_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.lambda_enabled && local.s3_logs_enabled

  attributes = ["logs-s3"]

  context = module.this.context
}

module "forwarder_log_artifact" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  source  = "cloudposse/module-artifact/external"
  version = "0.8.0"

  filename    = "forwarder-log.zip"
  module_name = var.dd_module_name
  module_path = path.module
  url         = local.forwarder_log_artifact_url
}

resource "aws_iam_role" "lambda_forwarder_log" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  name                 = module.forwarder_log_label.id
  path                 = var.forwarder_iam_path
  description          = "Datadog Lambda CloudWatch/S3 logs forwarder"
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  permissions_boundary = var.log_permissions_boundary
  tags                 = module.forwarder_log_label.tags

  # AWS will create the log group if needed. Make sure we create it first.
  depends_on = [aws_cloudwatch_log_group.forwarder_log]
}

resource "aws_iam_policy" "lambda_forwarder_log" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  name        = module.forwarder_log_label.id
  path        = var.forwarder_iam_path
  description = "Datadog Lambda CloudWatch/S3 logs forwarder"
  policy      = data.aws_iam_policy_document.lambda_default[0].json
  tags        = module.forwarder_log_label.tags
}

resource "aws_iam_role_policy_attachment" "lambda_forwarder_log" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  role       = aws_iam_role.lambda_forwarder_log[0].name
  policy_arn = aws_iam_policy.lambda_forwarder_log[0].arn
}

######################################################################
## Create lambda function

resource "aws_lambda_function" "forwarder_log" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  #checkov:skip=BC_AWS_GENERAL_64: (Pertaining to Lambda DLQ) Vendor lambda does not have a means to reprocess failed events.

  description                    = "Datadog Forwarder for CloudWatch/S3 logs"
  filename                       = module.forwarder_log_artifact[0].file
  function_name                  = module.forwarder_log_label.id
  role                           = aws_iam_role.lambda_forwarder_log[0].arn
  handler                        = "lambda_function.lambda_handler"
  source_code_hash               = module.forwarder_log_artifact[0].base64sha256
  runtime                        = var.lambda_runtime
  architectures                  = var.lambda_architectures
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions
  layers                         = var.forwarder_log_layers

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

  tags = module.forwarder_log_label.tags

  # AWS will create the log group if needed. Make sure we create it first.
  depends_on = [aws_cloudwatch_log_group.forwarder_log]
}

resource "aws_lambda_permission" "allow_s3_bucket" {
  for_each = local.s3_logs_enabled ? local.s3_bucket_names_to_authorize : []

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_log[0].arn
  principal     = "s3.amazonaws.com"
  source_arn    = "${local.arn_format}:s3:::${each.value}"
}

resource "aws_s3_bucket_notification" "s3_bucket_notification" {
  for_each = local.s3_logs_enabled ? toset(var.s3_buckets) : []

  bucket = each.key

  lambda_function {
    lambda_function_arn = aws_lambda_function.forwarder_log[0].arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_bucket]
}

resource "aws_s3_bucket_notification" "s3_bucket_notification_with_prefixes" {
  for_each = local.s3_logs_enabled ? var.s3_buckets_with_prefixes : {}

  bucket = each.value.bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.forwarder_log[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = each.value.bucket_prefix
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
    resources = concat(
      formatlist("%s:s3:::%s", local.arn_format, local.s3_bucket_names_to_authorize),
      formatlist("%s:s3:::%s/*", local.arn_format, local.s3_bucket_names_to_authorize)
    )
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

  dynamic "statement" {
    for_each = var.forwarder_use_cache_bucket ? [true] : []
    content {
      effect = "Allow"

      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListObject",
        "s3:DeleteObject",
      ]
      resources = [
        one(module.tags_cache_s3_bucket[*].bucket_arn),
        "${one(module.tags_cache_s3_bucket[*].bucket_arn)}/*"
      ]
    }
  }
}

resource "aws_iam_policy" "lambda_forwarder_log_s3" {
  count = local.s3_logs_enabled ? 1 : 0

  name        = module.forwarder_log_s3_label.id
  path        = var.forwarder_iam_path
  description = "Allow Datadog Lambda Logs Forwarder to access S3 buckets"
  policy      = join("", data.aws_iam_policy_document.s3_log_bucket[*].json)
  tags        = module.forwarder_log_s3_label.tags
}

resource "aws_iam_role_policy_attachment" "datadog_s3" {
  count = local.s3_logs_enabled ? 1 : 0

  role       = join("", aws_iam_role.lambda_forwarder_log[*].name)
  policy_arn = join("", aws_iam_policy.lambda_forwarder_log_s3[*].arn)
}

# Lambda Forwarder logs
resource "aws_cloudwatch_log_group" "forwarder_log" {
  count = local.lambda_enabled && var.forwarder_log_enabled ? 1 : 0

  name              = "/aws/lambda/${module.forwarder_log_label.id}"
  retention_in_days = var.forwarder_log_retention_days

  kms_key_id = var.kms_key_id

  tags = module.forwarder_log_label.tags
}

# CloudWatch Log Groups
resource "aws_lambda_permission" "cloudwatch_groups" {
  for_each = local.lambda_enabled && var.forwarder_log_enabled ? var.cloudwatch_forwarder_log_groups : {}

  statement_id  = "datadog-forwarder-${each.key}-permission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_log[0].function_name
  principal     = "logs.${local.aws_region}.amazonaws.com"
  source_arn    = "${local.arn_format}:logs:${local.aws_region}:${local.aws_account_id}:log-group:${each.value.name}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "cloudwatch_log_subscription_filter" {
  for_each = local.lambda_enabled && var.forwarder_log_enabled ? var.cloudwatch_forwarder_log_groups : {}

  name            = module.forwarder_log_label.id
  log_group_name  = each.value.name
  destination_arn = aws_lambda_function.forwarder_log[0].arn
  filter_pattern  = each.value.filter_pattern
}

resource "aws_lambda_permission" "allow_eventbridge" {
  for_each = local.lambda_enabled && var.forwarder_log_enabled ? var.cloudwatch_forwarder_event_patterns : {}

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder_log[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.cloudwatch_event[each.key].aws_cloudwatch_event_rule_arn
}

module "cloudwatch_event" {
  source  = "cloudposse/cloudwatch-events/aws"
  version = "0.6.1"

  for_each = local.lambda_enabled && var.forwarder_log_enabled ? var.cloudwatch_forwarder_event_patterns : {}

  name    = each.key
  context = module.forwarder_log_label.context

  cloudwatch_event_rule_description = "${each.key} events forwarded to Datadog"

  # Any optional attributes that are not set will equal null, and CloudWatch doesn't like that.
  cloudwatch_event_rule_pattern = { for k, v in each.value : k => v if v != null }
  cloudwatch_event_target_arn   = aws_lambda_function.forwarder_log[0].arn
}

module "tags_cache_s3_bucket" {
  # Bucket for storing lambda tags cache and logs which failed to post. https://docs.datadoghq.com/logs/guide/forwarder/?tab=cloudformation#upgrade-an-older-version-to-31060
  source  = "cloudposse/s3-bucket/aws"
  version = "4.10.0"

  count = local.lambda_enabled && var.forwarder_use_cache_bucket ? 1 : 0

  attributes = concat(module.forwarder_log_label.attributes, ["cache"])

  context = module.forwarder_log_label.context
}

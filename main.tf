data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
}

data "aws_partition" "current" {
  count = local.enabled ? 1 : 0
}

data "aws_region" "current" {
  count = local.enabled ? 1 : 0
}

locals {
  enabled        = module.this.enabled
  arn_format     = local.enabled ? "arn:${data.aws_partition.current[0].partition}" : ""
  aws_account_id = join("", data.aws_caller_identity.current.*.account_id)
  aws_region     = join("", data.aws_region.current.*.name)
  lambda_enabled = local.enabled

  dd_api_key_resource    = var.dd_api_key_source.resource
  dd_api_key_identifier  = var.dd_api_key_source.identifier
  dd_api_key_arn         = local.dd_api_key_resource == "ssm" ? join("", data.aws_ssm_parameter.api_key.*.arn) : local.dd_api_key_identifier
  dd_api_key_iam_actions = [lookup({ kms = "kms:Decrypt", asm = "secretsmanager:GetSecretValue", ssm = "ssm:GetParameter" }, local.dd_api_key_resource, "")]
  dd_api_key_kms         = local.dd_api_key_resource == "kms" ? { DD_KMS_API_KEY = var.dd_api_key_kms_ciphertext_blob } : {}
  dd_api_key_asm         = local.dd_api_key_resource == "asm" ? { DD_API_KEY_SECRET_ARN = local.dd_api_key_identifier } : {}
  dd_api_key_ssm         = local.dd_api_key_resource == "ssm" ? { DD_API_KEY_SSM_NAME = local.dd_api_key_identifier } : {}

  dd_site = { DD_SITE = var.forwarder_lambda_datadog_host }

  # Additional options for automated tag collection
  cache_enabled           = var.dd_fetch_lambda_tags || var.dd_fetch_log_group_tags
  dd_fetch_lambda_tags    = { DD_FETCH_LAMBDA_TAGS = var.dd_fetch_lambda_tags }
  dd_fetch_log_group_tags = { DD_FETCH_LOG_GROUP_TAGS = var.dd_fetch_log_group_tags }
  # the fetch tags options require an s3 bucket for Lambda tags cache
  dd_s3_bucket_name = local.cache_enabled ? {
    DD_S3_BUCKET_NAME = coalesce(var.dd_s3_bucket_name, module.dd_s3_bucket_name.id)
  } : {}

  # If map is supplied, merge map with context, or use only context
  # Convert map to dd tags equivalent
  dd_tags = length(var.dd_tags_map) > 0 ? [
    for tagk, tagv in var.dd_tags_map :
    tagv != null ? format("%s:%s", tagk, tagv) : tagk
  ] : var.dd_tags
  dd_tags_env = { DD_TAGS = join(",", local.dd_tags) }

  lambda_debug = var.forwarder_lambda_debug_enabled ? { DD_LOG_LEVEL = "debug" } : {}
  lambda_env = merge(
    local.dd_api_key_kms,
    local.dd_api_key_asm,
    local.dd_api_key_ssm,
    local.dd_site,
    local.lambda_debug,
    local.dd_fetch_lambda_tags,
    local.dd_fetch_log_group_tags,
    local.dd_s3_bucket_name,
    local.dd_tags_env
  )
}

module "dd_s3_bucket_name" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.lambda_enabled && local.cache_enabled

  attributes = ["datadog-cache"]

  context = module.this.context
}

module "dd_s3_bucket_cache" {
  count   = local.lambda_enabled && local.cache_enabled ? 1 : 0
  source  = "cloudposse/s3-bucket/aws"
  version = "0.41.0"

  bucket_name = module.dd_s3_bucket_name.id
  acl         = "private"

  context = module.this.context
}

# Log Forwarder, RDS Enhanced Forwarder, VPC Flow Log Forwarder

data "aws_ssm_parameter" "api_key" {
  count = local.lambda_enabled && local.dd_api_key_resource == "ssm" ? 1 : 0
  name  = local.dd_api_key_identifier
}

######################################################################
## Create a policy document to allow Lambda to assume role

data "aws_iam_policy_document" "assume_role" {
  count = local.lambda_enabled ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

######################################################################
## Create Lambda policy and attach it to the Lambda role

data "aws_iam_policy_document" "lambda_default" {
  count = local.lambda_enabled ? 1 : 0

  # #checkov:skip=BC_AWS_IAM_57: (Pertaining to constraining IAM write access) This policy has not write access and is restricted to one specific ARN.

  source_json = var.lambda_policy_source_json

  statement {
    sid = "AllowWriteLogs"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowGetOrDecryptApiKey"

    effect = "Allow"

    actions = local.dd_api_key_iam_actions

    resources = [local.dd_api_key_arn]
  }

  dynamic "statement" {
    for_each = var.dd_fetch_lambda_tags ? [true] : []
    content {
      sid    = "DdFetchLambdaTags"
      effect = "Allow"

      actions = [
        "tag:GetResources"
      ]
      resources = var.dd_fetch_lambda_tags_list
    }
  }

  dynamic "statement" {
    for_each = var.dd_fetch_log_group_tags ? [true] : []
    content {
      sid    = "DdFetchLogGroupTags"
      effect = "Allow"

      actions = [
        "logs:ListTagsLogGroup"
      ]
      resources = var.dd_fetch_log_group_tags_list
    }
  }

  dynamic "statement" {
    for_each = local.cache_enabled ? [true] : []
    content {
      sid    = "DdCacheAccessS3"
      effect = "Allow"

      actions = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = module.dd_s3_bucket_cache.bucket_arn
    }
  }
}

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
  enabled                   = module.this.enabled
  arn_format                = "arn:${data.aws_partition.current[0].partition}"
  aws_account_id            = join("", data.aws_caller_identity.current.*.account_id)
  aws_region                = join("", data.aws_region.current.*.name)
  lambda_enabled            = local.enabled
  dd_api_key_resource       = var.dd_api_key_source.resource
  dd_api_key_identifier     = var.dd_api_key_source.identifier
  dd_api_key_arn            = local.dd_api_key_resource == "ssm" ? join("", data.aws_ssm_parameter.api_key.*.arn) : local.dd_api_key_identifier

  dd_api_key_iam_actions    = [lookup({ kms = "kms:Decrypt", asm = "secretsmanager:GetSecretValue", ssm = "ssm:GetParameter" }, local.dd_api_key_resource, "")]
  dd_api_key_kms            = local.dd_api_key_resource == "kms" ? { DD_KMS_API_KEY = var.dd_api_key_kms_ciphertext_blob } : {}
  dd_api_key_asm            = local.dd_api_key_resource == "asm" ? { DD_API_KEY_SECRET_ARN = local.dd_api_key_identifier } : {}
  dd_api_key_ssm            = local.dd_api_key_resource == "ssm" ? { DD_API_KEY_SSM_NAME = local.dd_api_key_identifier } : {}
  lambda_debug              = var.forwarder_lambda_debug_enabled ? { DD_LOG_LEVEL = "debug" } : {}
  lambda_env                = merge(local.dd_api_key_kms, local.dd_api_key_asm, local.dd_api_key_ssm, local.lambda_debug)
  lambda_policy_source_json = var.lambda_policy_source_json
}

# Log Forwarder, RDS Enhanced Forwarder, VPC Flow Log Forwarder

data "aws_ssm_parameter" "api_key" {
  count = local.lambda_enabled && local.dd_api_key_resource == "ssm" ? 1 : 0
  name  = local.dd_api_key_identifier
}

module "lambda_label" {
  source     = "cloudposse/label/null"
  version    = "0.24.1" # requires Terraform >= 0.13.0
  attributes = ["forwarder-lambda"]

  context = module.this.context
}

######################################################################
## Create a policy document to assume role and a lambda role

data "aws_iam_policy_document" "assume" {
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

resource "aws_iam_role" "lambda" {
  count = local.lambda_enabled ? 1 : 0

  name               = module.lambda_label.id
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
  tags               = module.lambda_label.tags
}

######################################################################
## Create Lambda policy and attach it to the Lambda role

data "aws_iam_policy_document" "lambda" {
  count = local.lambda_enabled ? 1 : 0

  # #checkov:skip=BC_AWS_IAM_57: (Pertaining to contstraining IAM write access) This policy has not write access and is restricted to one specific ARN.

  source_json = var.lambda_policy_source_json 

  statement {
    sid = "AllowWriteLogs"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowGetOrDecryptApiKey"

    effect = "Allow"

    actions = local.dd_api_key_iam_actions

    resources = [local.dd_api_key_arn]
  }

}

resource "aws_iam_policy" "lambda" {
  count = local.lambda_enabled ? 1 : 0

  name        = module.lambda_label.id
  description = "Allow put logs and access to Datadog API key"
  policy      = data.aws_iam_policy_document.lambda[0].json
}

resource "aws_iam_role_policy_attachment" "lambda" {
  count = local.lambda_enabled ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = aws_iam_policy.lambda[0].arn
}

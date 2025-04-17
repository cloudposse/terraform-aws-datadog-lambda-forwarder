variable "subnet_ids" {
  description = "List of subnet IDs to use when deploying the Lambda Function in a VPC"
  type        = list(string)
  default     = null
}

variable "security_group_ids" {
  description = "List of security group IDs to use when the Lambda Function runs in a VPC"
  type        = list(string)
  default     = null
}

# https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
variable "lambda_memory_size" {
  type        = number
  description = "Amount of memory in MB your Lambda Function can use at runtime"
  default     = 128
}

variable "lambda_reserved_concurrent_executions" {
  type        = number
  description = "Amount of reserved concurrent executions for the lambda function. A value of 0 disables Lambda from being triggered and -1 removes any concurrency limitations. Defaults to Unreserved Concurrency Limits -1"
  default     = -1
}

variable "datadog_forwarder_lambda_environment_variables" {
  type        = map(string)
  default     = {}
  description = "Map of environment variables to pass to the Lambda Function"
}

variable "lambda_runtime" {
  type        = string
  description = "Runtime environment for Datadog Lambda"
  default     = "python3.11"
}

variable "lambda_architectures" {
  type        = list(string)
  description = "Instruction set architecture for your Lambda function. Valid values are [\"x86_64\"] and [\"arm64\"]."
  default     = null
}

variable "lambda_timeout" {
  type        = number
  description = "Amount of time your Datadog Lambda Function has to run in seconds"
  default     = 120
}

variable "tracing_config_mode" {
  type        = string
  description = "Can be either PassThrough or Active. If PassThrough, Lambda will only trace the request from an upstream service if it contains a tracing header with 'sampled=1'. If Active, Lambda will respect any tracing header it receives from an upstream service"
  default     = "PassThrough"
}

variable "dd_api_key_source" {
  description = "One of: ARN for AWS Secrets Manager (asm) to retrieve the Datadog (DD) api key, ARN for the KMS (kms) key used to decrypt the ciphertext_blob of the api key, or the name of the SSM (ssm) parameter used to retrieve the Datadog API key"
  type = object({
    resource   = string
    identifier = string
  })

  default = {
    resource   = ""
    identifier = ""
  }

  # Resource can be one of kms, asm, ssm ("" to disable all lambda resources)
  validation {
    condition     = can(regex("(kms|asm|ssm)", var.dd_api_key_source.resource)) || var.dd_api_key_source.resource == ""
    error_message = "Provide one, and only one, ARN for (kms, asm) or name (ssm) to retrieve or decrypt Datadog api key."
  }

  # Check KMS ARN format
  validation {
    condition     = var.dd_api_key_source.resource == "kms" ? can(regex("arn:.*:kms:.*:key/.*", var.dd_api_key_source.identifier)) : true
    error_message = "ARN for KMS key does not appear to be valid format (example: arn:aws:kms:us-west-2:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab)."
  }

  # Check ASM ARN format
  validation {
    condition     = var.dd_api_key_source.resource == "asm" ? can(regex("arn:.*:secretsmanager:.*:secret:.*", var.dd_api_key_source.identifier)) : true
    error_message = "ARN for AWS Secrets Manager (asm) does not appear to be valid format (example: arn:aws:secretsmanager:us-west-2:111122223333:secret:aes128-1a2b3c)."
  }

  # Check SSM name format
  validation {
    condition     = var.dd_api_key_source.resource == "ssm" ? can(regex("^[a-zA-Z0-9_./-]+$", var.dd_api_key_source.identifier)) || can(regex("^arn:[^:]*:ssm:[^:]*:[^:]*:parameter/[a-zA-Z0-9_./-]+$", var.dd_api_key_source.identifier)) : true
    error_message = "API key source identifier must either be full arn or name of SSM parameter. Acceptable characters for name are `a-zA-Z0-9_.-` and `/` to delineate hierarchies."
  }
}

variable "dd_api_key_kms_ciphertext_blob" {
  type        = string
  description = "CiphertextBlob stored in environment variable DD_KMS_API_KEY used by the lambda function, along with the KMS key, to decrypt Datadog API key"
  default     = ""
}

variable "dd_artifact_filename" {
  type        = string
  description = "The Datadog artifact filename minus extension"
  default     = "aws-dd-forwarder"
}

variable "dd_module_name" {
  type        = string
  description = "The Datadog GitHub repository name"
  default     = "datadog-serverless-functions"
}

variable "dd_forwarder_version" {
  type        = string
  description = "Version tag of Datadog lambdas to use. https://github.com/DataDog/datadog-serverless-functions/releases"
  default     = "3.116.0"
}

variable "forwarder_log_enabled" {
  type        = bool
  description = "Flag to enable or disable Datadog log forwarder"
  default     = false
}

variable "forwarder_rds_enabled" {
  type        = bool
  description = "Flag to enable or disable Datadog RDS enhanced monitoring forwarder"
  default     = false
}

variable "forwarder_vpc_logs_enabled" {
  type        = bool
  description = "Flag to enable or disable Datadog VPC flow log forwarder"
  default     = false
}

variable "forwarder_log_retention_days" {
  type        = number
  description = "Number of days to retain Datadog forwarder lambda execution logs. One of [0 1 3 5 7 14 30 60 90 120 150 180 365 400 545 731 1827 3653]"
  default     = 14
}

variable "kms_key_id" {
  type        = string
  description = "Optional KMS key ID to encrypt Datadog Lambda function logs"
  default     = null
}

variable "s3_buckets" {
  type        = list(string)
  description = "The names of S3 buckets to forward logs to Datadog"
  default     = []
}

variable "s3_buckets_with_prefixes" {
  type        = map(object({ bucket_name : string, bucket_prefix : string }))
  description = "The names S3 buckets and prefix to forward logs to Datadog"
  default     = {}
}

variable "s3_bucket_kms_arns" {
  type        = list(string)
  description = "List of KMS key ARNs for s3 bucket encryption"
  default     = []
}

variable "cloudwatch_forwarder_log_groups" {
  type = map(object({
    name           = string
    filter_pattern = string
  }))
  description = <<EOT
    Map of CloudWatch Log Groups with a filter pattern that the Lambda forwarder will send logs from. For example: { mysql1 = { name = "/aws/rds/maincluster", filter_pattern = "" }
    EOT
  default     = {}
}

variable "forwarder_lambda_debug_enabled" {
  type        = bool
  description = "Whether to enable or disable debug for the Lambda forwarder"
  default     = false
}

variable "vpclogs_cloudwatch_log_group" {
  type        = string
  description = "The name of the CloudWatch Log Group for VPC flow logs"
  default     = null
}

variable "forwarder_rds_artifact_url" {
  type        = string
  description = "The URL for the code of the Datadog forwarder for RDS. It can be a local file, url or git repo"
  default     = null
}

variable "forwarder_vpc_logs_artifact_url" {
  type        = string
  description = "The URL for the code of the Datadog forwarder for VPC Logs. It can be a local file, url or git repo"
  default     = null
}

variable "forwarder_log_artifact_url" {
  type        = string
  description = "The URL for the code of the Datadog forwarder for Logs. It can be a local file, URL or git repo"
  default     = null
}

variable "lambda_policy_source_json" {
  type        = string
  description = "Additional IAM policy document that can optionally be passed and merged with the created policy document"
  default     = ""
}

variable "lambda_custom_policy_name" {
  type        = string
  description = "Additional IAM policy document that can optionally be passed and merged with the created policy document"
  default     = "DatadogForwarderCustomPolicy"
}

variable "forwarder_iam_path" {
  type        = string
  description = "Path to the IAM roles and policies created"
  default     = "/"
}

variable "forwarder_lambda_datadog_host" {
  type        = string
  description = "Datadog Site to send data to. Possible values are `datadoghq.com`, `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com` and `ddog-gov.com`"
  default     = "datadoghq.com"
  validation {
    condition     = contains(["datadoghq.com", "datadoghq.eu", "us3.datadoghq.com", "us5.datadoghq.com", "ddog-gov.com"], var.forwarder_lambda_datadog_host)
    error_message = "Invalid host: possible values are `datadoghq.com`, `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com` and `ddog-gov.com`."
  }
}

variable "forwarder_log_layers" {
  type        = list(string)
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to Datadog log forwarder lambda function"
  default     = []
}

variable "forwarder_rds_layers" {
  type        = list(string)
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to Datadog RDS enhanced monitoring lambda function"
  default     = []
}

variable "forwarder_vpc_logs_layers" {
  type        = list(string)
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to Datadog VPC flow log forwarder lambda function"
  default     = []
}

variable "forwarder_rds_filter_pattern" {
  type        = string
  description = "Filter pattern for Lambda forwarder RDS"
  default     = ""
}

variable "forwarder_vpclogs_filter_pattern" {
  type        = string
  description = "Filter pattern for Lambda forwarder VPC Logs"
  default     = ""
}

variable "dd_tags" {
  type        = list(string)
  description = "A list of Datadog tags to apply to all logs forwarded to Datadog"
  default     = []
}

variable "dd_tags_map" {
  type        = map(string)
  description = "A map of Datadog tags to apply to all logs forwarded to Datadog. This will override dd_tags."
  default     = {}
}

variable "log_permissions_boundary" {
  type        = string
  description = "ARN of the policy that is used to set the permissions boundary for the lambda-log role managed by this module."
  default     = null
}

variable "vpc_logs_permissions_boundary" {
  type        = string
  description = "ARN of the policy that is used to set the permissions boundary for the lambda-vpc-logs role managed by this module."
  default     = null
}

variable "rds_permissions_boundary" {
  type        = string
  description = "ARN of the policy that is used to set the permissions boundary for the lambda-rds role managed by this module."
  default     = null
}

variable "api_key_ssm_arn" {
  type        = string
  description = <<-EOF
    ARN of the SSM parameter for the Datadog API key.
    Passing this removes the need to fetch the key from the SSM parameter store.
    This could be the case if the SSM Key is in a different region than the lambda.
  EOF
  default     = null
}

variable "cloudwatch_forwarder_event_patterns" {
  type = map(object({
    version     = optional(list(string))
    id          = optional(list(string))
    detail-type = optional(list(string))
    source      = optional(list(string))
    account     = optional(list(string))
    time        = optional(list(string))
    region      = optional(list(string))
    resources   = optional(list(string))
    detail      = optional(map(list(string)))
  }))
  description = <<-EOF
    Map of title => CloudWatch Event patterns to forward to Datadog. Event structure from here: <https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/CloudWatchEventsandEventPatterns.html#CloudWatchEventsPatterns>
    Example:
    ```hcl
    cloudwatch_forwarder_event_rules = {
      "guardduty" = {
        source = ["aws.guardduty"]
        detail-type = ["GuardDuty Finding"]
      }
      "ec2-terminated" = {
        source = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
        detail = {
          state = ["terminated"]
        }
      }
    }
    ```
  EOF
  default     = {}
}

variable "forwarder_use_cache_bucket" {
  type        = bool
  description = "Flag to enable or disable the cache bucket for lambda tags and failed events. See https://docs.datadoghq.com/logs/guide/forwarder/?tab=cloudformation#upgrade-an-older-version-to-31060. Recommended for forwarder versions 3.106 and higher."
  default     = true
}

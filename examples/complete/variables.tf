variable "region" {
  type        = string
  description = "AWS region"
}

variable "dd_api_key_source" {
  description = "One of: ARN for AWS Secrets Manager (asm) to retrieve the Datadog (DD) api key, ARN for the KMS (kms) key used to decrypt the ciphertext_blob of the api key, or the name of the SSM (ssm) parameter used to retrieve the Datadog API key."
  type = object({
    resource   = string
    identifier = string
  })

  default = {
    resource   = "ssm"
    identifier = "/datadog/datadog_api_key"
  }

  # Resource can be one of kms, asm, ssm ("" to disable all lambda resources)
  validation {
    condition     = can(regex("(kms|asm|ssm)", var.dd_api_key_source.resource)) || var.dd_api_key_source.resource == ""
    error_message = "Provide one, and only one, ARN for (kms, asm) or name (ssm) to retrieve or decrypt Datadog api key."
  }

  # Check KMS ARN format
  validation {
    condition     = var.dd_api_key_source.resource == "kms" ? can(regex("arn:aws:kms:.*:key/.*", var.dd_api_key_source.identifier)) : true
    error_message = "ARN for KMS key does not appear to be valid format (example: arn:aws:kms:us-west-2:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab)."
  }

  # Check ASM ARN format
  validation {
    condition     = var.dd_api_key_source.resource == "asm" ? can(regex("arn:aws:secretsmanager:.*:secret:.*", var.dd_api_key_source.identifier)) : true
    error_message = "ARN for AWS Secrets Manager (asm) does not appear to be valid format (example: arn:aws:secretsmanager:us-west-2:111122223333:secret:aes128-1a2b3c)."
  }

  # Check SSM name format
  validation {
    condition     = var.dd_api_key_source.resource == "ssm" ? can(regex("^[a-zA-Z0-9_./-]+$", var.dd_api_key_source.identifier)) : true
    error_message = "Name for SSM parameter does not appear to be valid format, acceptable characters are `a-zA-Z0-9_.-` and `/` to delineate hierarchies."
  }
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

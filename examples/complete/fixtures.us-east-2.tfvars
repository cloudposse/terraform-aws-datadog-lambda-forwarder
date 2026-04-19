region = "us-east-2"

namespace = "eg"

tenant = "someval"

environment = "ue2"

stage = "test"

name = "datadog-lambda-forwarder"

# Include `tenant` in `label_order` so the cloudwatch-events sub-module
# (used when `cloudwatch_forwarder_event_patterns` is set) exercises the
# 6-dimension label path. Without this, older versions of
# `cloudposse/label/null` (`<= 0.22.0`) fail with `Invalid index` on
# `local.id_context["tenant"]`.
label_order = ["namespace", "tenant", "environment", "stage", "name", "attributes"]

dd_api_key_source = {
  resource   = "ssm"
  identifier = "/datadog/datadog_api_key"
}

cloudwatch_forwarder_event_patterns = {
  "guardduty" = {
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  }
  "cloudtrail" = {
    source      = ["aws.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]
  }
}

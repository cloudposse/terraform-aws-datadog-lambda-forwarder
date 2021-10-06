region = "us-east-2"

namespace = "eg"

environment = "ue2"

stage = "test"

name = "datadog-lambda-forwarder"

dd_api_key_source = {
  resource   = "ssm"
  identifier = "/datadog/datadog_api_key"
}

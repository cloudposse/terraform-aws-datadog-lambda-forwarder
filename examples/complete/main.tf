module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "0.25.0"

  cidr_block = "172.16.0.0/16"

  context = module.this.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "0.39.3"

  availability_zones   = ["us-east-2a", "us-east-2b"]
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = false
  nat_instance_enabled = false

  context = module.this.context
}

module "cloudwatch-logs" {
  source  = "cloudposse/cloudwatch-logs/aws"
  version = "0.4.3"
  name    = "postgresql"
  context = module.this.context
}

resource "aws_ssm_parameter" "datadog_key" {
  name        = "/datadog/api-key"
  description = "The parameter description"
  type        = "SecureString"
  value       = "testkey"
}

module "datadog_lambda_forwarder" {
  source                = "../.."
  forwarder_log_enabled = true
  cloudwatch_forwarder_log_groups = {
    postgres = module.cloudwatch-logs.log_group_name
  }
  dd_api_key_source = var.dd_api_key_source

  context = module.this.context
  depends_on = [aws_ssm_parameter.datadog_key]
}

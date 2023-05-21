terraform {
  required_version = ">= 1.3.0"

  required_providers {
    # Update these to reflect the actual requirements of your module
    local = {
      source  = "hashicorp/local"
      version = ">= 1.2"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0"
    }
  }
}

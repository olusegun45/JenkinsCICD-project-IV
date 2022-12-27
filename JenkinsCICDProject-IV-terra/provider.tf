terraform {
  required_version = "1.3.6"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.39.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region                   = "us-east-2"
  profile                  = "default"
}


 
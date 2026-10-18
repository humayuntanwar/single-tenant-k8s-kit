terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Production: an encrypted S3 backend with locking, one state per customer
}

#• provider "aws" says which AWS region to build in.
provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = {
      customer   = "customer-b" #• default_tags stamps every single resource with customer = customer-b. Your bill can then be split per customer, and an auditor can see who owns what.
      managed-by = "terraform"
    }
  }
}
# has no value in the file. You pass your IP address on the command line, so it's never saved in Git.
variable "admin_cidr" {
  type = string
}
#uses the recipe with customer-b's name and address range.
module "customer_env" {
  source        = "../../modules/customer-env"
  customer_name = "customer-b"
  vpc_cidr      = "10.20.0.0/16"
  admin_cidr    = var.admin_cidr
}

output "cluster_name" {
  value = module.customer_env.cluster_name
}
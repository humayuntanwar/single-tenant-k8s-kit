data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  #two zines
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.customer_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  #private subnets for the nodes; public subnet only for NAT and load Balancers
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 48), cidrsubnet(var.vpc_cidr, 8, 49)]

  enable_nat_gateway = true
  single_nat_gateway = true #saves cost; production would use one per zone
  
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.customer_name}-eks"
  kubernetes_version = var.kubernates_version

  # this API endpoint is reachable only from the admin_cidr 

  endpoint_public_access       = true
  endpoint_public_access_cidrs = [var.admin_cidr]

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns                = {}
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets #nodes only in private dsubnet

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_ARM_64_STANDARD" #ARM (Graviton)
      instance_types = ["t4g.small"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }

  }
}

#  this file builds the whole environment. Instead of writing every piece by hand, it uses two well-known community modules: terraform-aws-modules/vpc and /eks.
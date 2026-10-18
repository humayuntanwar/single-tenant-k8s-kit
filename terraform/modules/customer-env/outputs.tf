#values the recipe hands back after building: the cluster's name, its API address and the network's ID. They print at the end of apply, and other code can use them.
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
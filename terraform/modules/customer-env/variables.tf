variable "customer_name" {
  description = "Short customer name, used to name and tag everything"
  type        = string

}

variable "vpc_cidr" {
  description = "Private address range for this customer's network, e.g. 10.10.0.0/16"
  type        = string
}

variable "admin_cidr" {
  description = "The only IP range allowed to reach the cluster API, e.g. your IP with /32"
  type        = string
}

variable "kubernates_version" {
  description = "EKS Kubernetes version; use one currently supported by EKS"
  type        = string
  default     = "1.33"
}
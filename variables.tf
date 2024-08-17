# variable "cidr_block" {
#   type        = string
#   description = "VPC CIDR"
# }

# variable "private_subnets" {
#   description = "Subnets CIDR"
#   type        = list(string)
# }

# variable "public_subnets" {
#   description = "Subnets CIDR"
#   type        = list(string)
# }

variable "cluster_name" {
  description = "Cluster name"
  type        = string
}

variable "vpc_id" {
  type        = string
}


variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "lgmt-demo"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use"
  type        = number
  default     = 2
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "EC2 instance types for node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Min node count"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Max node count"
  type        = number
  default     = 3
}

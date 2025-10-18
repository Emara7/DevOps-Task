module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnets  = [for i, az in slice(data.aws_availability_zones.available.names, 0, var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = [for i, az in slice(data.aws_availability_zones.available.names, 0, var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

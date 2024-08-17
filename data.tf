data "aws_availability_zones" "azs" {}

data "aws_subnet" "public" {
  filter {
    name   = "tag:Name"
    values = ["jenkins-subnet"]
  }
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["private-subnet"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}
locals {
name_prefix = "static-site"
}


# Optional simple VPC creation if user didn't supply VPC/subnets
resource "aws_vpc" "this" {
count = var.vpc_id == "" ? 1 : 0
cidr_block = "10.0.0.0/16"
tags = { Name = "${local.name_prefix}-vpc" }
}


resource "aws_subnet" "public" {
count = length(var.public_subnet_ids) > 0 ? 0 : 2
vpc_id = aws_vpc.this[0].id
cidr_block = cidrsubnet(aws_vpc.this[0].cidr_block, 8, count.index)
map_public_ip_on_launch = true
availability_zone = data.aws_availability_zones.available.names[count.index]
tags = { Name = "${local.name_prefix}-public-${count.index}" }
}


data "aws_availability_zones" "available" {}


# compute final subnet ids list
locals {
subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : aws_subnet.public[*].id
}


# Security Group for ALB
resource "aws_security_group" "alb_sg" {
name = "${local.name_prefix}-alb-sg"
vpc_id = coalescelist([var.vpc_id], [aws_vpc.this[0].id])[0]
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}


# Security Group for instances
resource "aws_security_group" "instance_sg" {
name = "${local.name_prefix}-instance-sg"
vpc_id = coalescelist([var.vpc_id], [aws_vpc.this[0].id])[0]
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
security_groups = [aws_security_group.alb_sg.id]
}
egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}


# IAM role for instance to allow pulling from GitHub public repo (not required) and CloudWatch logs (optional)
resource "aws_iam_role" "ec2_role" {
name = "${local.name_prefix}-ec2-role"
assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}


data "aws_iam_policy_document" "ec2_assume_role" {
statement {
actions = ["sts:AssumeRole"]
principals { type = "Service"; identifiers = ["ec2.amazonaws.com"] }
}
}


resource "aws_iam_role_policy_attachment" "cw" {
value = aws_lb.alb.dns_name
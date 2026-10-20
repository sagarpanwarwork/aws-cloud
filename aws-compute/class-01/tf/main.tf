terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# ---------------------------------------------------------
# 1. Retrieve the latest Amazon Linux 2023 x86_64 AMI
# ---------------------------------------------------------
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------
# 2. Create the VPC
# ---------------------------------------------------------
resource "aws_vpc" "run_lab" {
  cidr_block           = "10.80.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-run-lab"
  }
}

# ---------------------------------------------------------
# 3. Create public subnets in two Availability Zones
# ---------------------------------------------------------
resource "aws_subnet" "run_a" {
  vpc_id                  = aws_vpc.run_lab.id
  cidr_block              = "10.80.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-run-a"
  }
}

resource "aws_subnet" "run_b" {
  vpc_id                  = aws_vpc.run_lab.id
  cidr_block              = "10.80.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-run-b"
  }
}

# ---------------------------------------------------------
# 4. Create and attach the Internet Gateway
# ---------------------------------------------------------
resource "aws_internet_gateway" "run_lab" {
  vpc_id = aws_vpc.run_lab.id

  tags = {
    Name = "igw-run-lab"
  }
}

# ---------------------------------------------------------
# 5. Create the public route table
# ---------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.run_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.run_lab.id
  }

  tags = {
    Name = "rtb-run-public"
  }
}

# Use for_each to associate both public subnets
locals {
  public_subnets = {
    run_a = aws_subnet.run_a.id
    run_b = aws_subnet.run_b.id
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = each.value
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------
# 6. Security group for the Application Load Balancer
# ---------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "run-alb-sg"
  description = "Allow public HTTP to the demo ALB"
  vpc_id      = aws_vpc.run_lab.id

  ingress {
    description = "HTTP from the internet for the temporary lab"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic for the demo"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-run-alb"
  }
}

# ---------------------------------------------------------
# 7. Security group for the EC2 application servers
# ---------------------------------------------------------
resource "aws_security_group" "targets" {
  name        = "run-targets-sg"
  description = "Allow HTTP from the ALB security group only"
  vpc_id      = aws_vpc.run_lab.id

  ingress {
    description     = "HTTP from the ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic for package installation and demo"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-run-targets"
  }
}

# ---------------------------------------------------------
# 8. Launch EC2 instance A
# ---------------------------------------------------------
resource "aws_instance" "run_a" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.run_a.id
  vpc_security_group_ids      = [aws_security_group.targets.id]
  associate_public_ip_address = true

  user_data = templatefile(
    "${path.module}/templates/httpd-user-data.sh.tftpl",
    {
      target_name = "TARGET A"
    }
  )

  # Ensure the public route is configured before booting the instance.
  depends_on = [
    aws_route_table_association.public
  ]

  tags = {
    Name = "ec2-run-a"
    Lab  = "aws-compute"
  }
}

# ---------------------------------------------------------
# 9. Launch EC2 instance B
# ---------------------------------------------------------
resource "aws_instance" "run_b" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.run_b.id
  vpc_security_group_ids      = [aws_security_group.targets.id]
  associate_public_ip_address = true

  user_data = templatefile(
    "${path.module}/templates/httpd-user-data.sh.tftpl",
    {
      target_name = "TARGET B"
    }
  )

  depends_on = [
    aws_route_table_association.public
  ]

  tags = {
    Name = "ec2-run-b"
    Lab  = "aws-compute"
  }
}

# ---------------------------------------------------------
# 10. Create the target group
# ---------------------------------------------------------
resource "aws_lb_target_group" "web" {
  name             = "tg-run-web"
  target_type      = "instance"
  protocol         = "HTTP"
  port             = 80
  ip_address_type  = "ipv4"
  protocol_version = "HTTP1"
  vpc_id           = aws_vpc.run_lab.id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name = "tg-run-web"
  }
}

# ---------------------------------------------------------
# 11. Register both EC2 instances with the target group
# ---------------------------------------------------------
resource "aws_lb_target_group_attachment" "target_a" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.run_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "target_b" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.run_b.id
  port             = 80
}

# ---------------------------------------------------------
# 12. Create the Application Load Balancer
# ---------------------------------------------------------
resource "aws_lb" "web" {
  name               = "alb-run-web"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.run_a.id,
    aws_subnet.run_b.id
  ]

  # Ensure the internet routes and subnet associations exist first.
  depends_on = [
    aws_route_table_association.public
  ]

  tags = {
    Name = "alb-run-web"
    Lab  = "aws-compute"
  }
}

# ---------------------------------------------------------
# 13. Configure the HTTP listener
# ---------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ---------------------------------------------------------
# 14. Outputs
# ---------------------------------------------------------
output "alb_dns_name" {
  description = "DNS name of the public Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "alb_url" {
  description = "URL to test the demo web application"
  value       = "http://${aws_lb.web.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the web target group"
  value       = aws_lb_target_group.web.arn
}

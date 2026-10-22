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

# Latest AWS-published Amazon Linux 2023 x86_64 AMI in this Region.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ------------------------------------------------------------------
# 1. VPC and two public subnets
# Classroom simplification: instances have public IPv4 for package
# installation and Systems Manager connectivity. Target SG blocks
# direct inbound HTTP. For production, prefer private app subnets.
# ------------------------------------------------------------------
resource "aws_vpc" "run_scale" {
  cidr_block           = "10.90.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-run-scale"
    Lab  = "aws-compute-scale"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.run_scale.id
  cidr_block              = "10.90.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-run-scale-a"
    Lab  = "aws-compute-scale"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.run_scale.id
  cidr_block              = "10.90.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-run-scale-b"
    Lab  = "aws-compute-scale"
  }
}

resource "aws_internet_gateway" "run_scale" {
  vpc_id = aws_vpc.run_scale.id

  tags = {
    Name = "igw-run-scale"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.run_scale.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.run_scale.id
  }

  tags = {
    Name = "rtb-run-scale-public"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------
# 2. Security groups
# ------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "run-scale-alb-sg"
  description = "Allow public HTTP to the demo ALB"
  vpc_id      = aws_vpc.run_scale.id

  ingress {
    description = "HTTP for the temporary classroom demo"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow the ALB to reach web targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-run-scale-alb"
    Lab  = "aws-compute-scale"
  }
}

resource "aws_security_group" "targets" {
  name        = "run-scale-targets-sg"
  description = "Allow web traffic only from the ALB security group"
  vpc_id      = aws_vpc.run_scale.id

  ingress {
    description     = "HTTP from the ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound package and Systems Manager traffic"
    from_port   = 0
    to_port     = 0
    # Check README.md at 001
    protocol    = "-1" # all IP protocols (such as TCP, UDP, ICMP, and all others) are allowed
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-run-scale-targets"
    Lab  = "aws-compute-scale"
  }
}

# ------------------------------------------------------------------
# 3. EC2 role for Systems Manager Run Command (no SSH required)
# ------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_managed_instance" {
  name               = "role-run-scale-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "role-run-scale-ssm"
    Lab  = "aws-compute-scale"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_managed_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "profile-run-scale-web"
  role = aws_iam_role.ssm_managed_instance.name
}

# ------------------------------------------------------------------
# 4. Target group and ALB
# ------------------------------------------------------------------
resource "aws_lb_target_group" "web" {
  name             = "tg-run-scale-web"
  target_type      = "instance"
  protocol         = "HTTP"
  port             = 80
  vpc_id           = aws_vpc.run_scale.id
  protocol_version = "HTTP1"

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
    Name = "tg-run-scale-web"
    Lab  = "aws-compute-scale"
  }
}

resource "aws_lb" "web" {
  name               = "alb-run-scale-web"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [aws_security_group.alb.id]
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  depends_on = [
    aws_route_table_association.public_a,
    aws_route_table_association.public_b
  ]

  tags = {
    Name = "alb-run-scale-web"
    Lab  = "aws-compute-scale"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ------------------------------------------------------------------
# 5. Launch template: recipe for every EC2 instance in the ASG
# ------------------------------------------------------------------
resource "aws_launch_template" "web" {
  name_prefix   = "lt-run-scale-web-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t3.micro"

  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.targets.id]
  }

  # One-minute EC2 metrics improve the responsiveness of the class demo.
  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -euxo pipefail

    dnf install -y httpd
    systemctl enable --now httpd

    TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

    cat > /var/www/html/index.html <<HTML
    <!doctype html>
    <html>
    <head><title>AWS Compute Scale Lab</title></head>
    <body>
      <h1>AWS Compute Scale Lab</h1>
      <p>Served by an Auto Scaling Group instance.</p>
      <p>Instance ID: $${INSTANCE_ID}</p>
      <p>Availability Zone: $${AZ}</p>
    </body>
    </html>
    HTML
  USERDATA
  )

  depends_on = [aws_iam_role_policy_attachment.ssm_core]

}

# ------------------------------------------------------------------
# 6. Auto Scaling Group: maintain capacity and attach to the ALB
# ------------------------------------------------------------------
resource "aws_autoscaling_group" "web" {
  name             = "asg-run-web"
  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  target_group_arns   = [aws_lb_target_group.web.arn]

  # Enable useful ASG metrics for the classroom demonstration.
  metrics_granularity = "1Minute"

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
    "GroupInServiceCapacity",
    "GroupPendingCapacity",
    "GroupTerminatingCapacity",
    "GroupTotalCapacity"
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "ec2-run-scale-web"
    propagate_at_launch = true
  }

  tag {
    key                 = "Lab"
    value               = "aws-compute-scale"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]

  # Let the scaling policy manage desired capacity after initial creation.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ------------------------------------------------------------------
# 7. Target tracking policy: keep average ASG CPU near 50 percent
# ------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                      = "policy-run-scale-cpu-50"
  policy_type               = "TargetTrackingScaling"
  autoscaling_group_name    = aws_autoscaling_group.web.name
  estimated_instance_warmup = 180

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}

# ------------------------------------------------------------------
# 8. Outputs
# ------------------------------------------------------------------
output "alb_url" {
  description = "Open this HTTP URL to test the scaled web tier"
  value       = "http://${aws_lb.web.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group to inspect in the EC2 console"
  value       = aws_autoscaling_group.web.name
}

output "target_group_name" {
  description = "Target group to inspect target health"
  value       = aws_lb_target_group.web.name
}

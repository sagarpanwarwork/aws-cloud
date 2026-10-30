variable "aws_region" {
  description = "AWS Region used for the classroom lab. Mumbai is the default."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short prefix used in AWS resource names. Keep it short for ALB naming limits."
  type        = string
  default     = "za-cw14"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,16}$", var.project_name))
    error_message = "project_name must be 3-16 characters containing lowercase letters, numbers, or hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the isolated classroom VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the Auto Scaling Group. t3.micro is a small classroom default."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Initial desired capacity. Auto Scaling may change this after deployment."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances allowed during the scaling demonstration."
  type        = number
  default     = 4
}

variable "create_target_tracking_policy_with_terraform" {
  description = "Set true to create CPU target tracking using Terraform. Leave false to create it in the EC2 console during class."
  type        = bool
  default     = false
}

variable "create_5xx_alarm_with_terraform" {
  description = "Set true to create the ALB target 5XX CloudWatch alarm using Terraform. Leave false to create it in the CloudWatch console during class."
  type        = bool
  default     = false
}

variable "allowed_http_cidrs" {
  description = "Client CIDR ranges allowed to access the demo ALB over HTTP. Use a narrower CIDR when possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

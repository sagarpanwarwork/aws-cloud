terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

################## VARIABLES ##################

variable "aws_region" {
  description = "AWS Region in which EC2 lifecycle actions are permitted."
  type        = string
  default     = "ap-south-1"
}

variable "trusted_public_ip_cidr" {
  description = "Trusted public egress IPv4 CIDR. For one IP, use x.x.x.x/32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.trusted_public_ip_cidr))
    error_message = "Provide a valid IPv4 CIDR, such as 203.0.113.25/32. Use your real public egress IP, not this documentation example."
  }
}

variable "role_name" {
  description = "Name of the IAM role that students will assume."
  type        = string
  default     = "DevOps-Operator-Role"
}

variable "policy_name" {
  description = "Name of the IAM permissions policy attached to the role."
  type        = string
  default     = "DevOps-Operator-Policy"
}

variable "classroom_tag_key" {
  description = "Only EC2 instances with this tag are eligible for lifecycle operations."
  type        = string
  default     = "Classroom"
}

variable "classroom_tag_value" {
  description = "Required value of the classroom tag."
  type        = string
  default     = "true"
}

################## Provider ##################
provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  classroom_instance_arn = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
}

# Trust policy: delegates role assumption to principals in this AWS account.
# The caller must ALSO have identity-based permission for sts:AssumeRole.
resource "aws_iam_role" "devops_operator" {
  name                 = var.role_name
  description          = "Classroom role for source-IP-restricted EC2 operations"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TrustPrincipalsInThisAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose = "AWS-classroom-demo"
  }
}

# Permissions policy: allows EC2 discovery and selected lifecycle actions.
# Start/stop/reboot are limited to instances tagged Classroom=true by default.
# An explicit Deny overrides any Allow when the public source IP is outside the
# configured CIDR. This is a public-source-IP demo, not a general VPC identity check.
resource "aws_iam_policy" "devops_operator" {
  name        = var.policy_name
  description = "Restricted EC2 operations with a trusted public source IP condition"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Discovery"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "AllowLifecycleActionsOnTaggedClassroomInstances"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances"
        ]
        Resource = local.classroom_instance_arn
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/${var.classroom_tag_key}" = var.classroom_tag_value
          }
        }
      },
      {
        Sid      = "ExplicitDenyIfOutsideTrustedPublicIP"
        Effect   = "Deny"
        Action   = "ec2:*"
        Resource = "*"
        Condition = {
          NotIpAddress = {
            "aws:SourceIp" = [var.trusted_public_ip_cidr]
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "AWS-classroom-demo"
  }
}

resource "aws_iam_role_policy_attachment" "devops_operator" {
  role       = aws_iam_role.devops_operator.name
  policy_arn = aws_iam_policy.devops_operator.arn
}

output "aws_account_id" {
  description = "AWS account in which Terraform created the role."
  value       = data.aws_caller_identity.current.account_id
}

output "role_arn" {
  description = "Use this ARN with aws sts assume-role."
  value       = aws_iam_role.devops_operator.arn
}

output "trusted_public_ip_cidr" {
  description = "CIDR allowed by the explicit source-IP Deny guardrail."
  value       = var.trusted_public_ip_cidr
}

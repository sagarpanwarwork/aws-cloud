output "application_url" {
  description = "Open this URL in a browser to generate ALB requests."
  value       = "http://${aws_lb.application.dns_name}"
}

output "application_error_test_url" {
  description = "This endpoint intentionally returns HTTP 500 to generate target 5XX metrics."
  value       = "http://${aws_lb.application.dns_name}/error"
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.application.name
}

output "load_balancer_metric_dimension" {
  description = "Exact LoadBalancer dimension value for AWS/ApplicationELB metrics."
  value       = aws_lb.application.arn_suffix
}

output "target_group_metric_dimension" {
  description = "Exact TargetGroup dimension value for AWS/ApplicationELB metrics."
  value       = aws_lb_target_group.application.arn_suffix
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "application_log_group" {
  value = aws_cloudwatch_log_group.application.name
}

output "ssm_target_tag" {
  description = "Use this tag to target the lab instances in Systems Manager Run Command."
  value       = "Lab=CloudWatch-ASG-Lab"
}

output "aws_region" {
  value = var.aws_region
}

output "target_tracking_policy_managed_by_terraform" {
  value = var.create_target_tracking_policy_with_terraform
}

output "target_5xx_alarm_managed_by_terraform" {
  value = var.create_5xx_alarm_with_terraform
}

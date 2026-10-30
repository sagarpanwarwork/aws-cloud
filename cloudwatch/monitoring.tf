resource "aws_sns_topic" "alerts" {
  name = "academy-class14-alerts"

  tags = {
    Name = "academy-class14-alerts"
  }
}

data "aws_iam_policy_document" "sns_cloudwatch_publish" {
  # Preserve owner management access while granting CloudWatch permission to publish.
  statement {
    sid    = "AllowAccountOwnerManagement"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    # SNS topic resource policies accept the documented SNS topic actions.
    # Use explicit actions rather than the broad SNS:* wildcard here.
    actions = [
      "sns:AddPermission",
      "sns:DeleteTopic",
      "sns:GetDataProtectionPolicy",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTagsForResource",
      "sns:Publish",
      "sns:PutDataProtectionPolicy",
      "sns:RemovePermission",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
    ]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid    = "AllowCloudWatchAlarmsToPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:*"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_cloudwatch_publish.json
}

# Optional: leave false to create this metric alarm in the CloudWatch console during class.
# The metric is TARGET-generated 5XX responses, not load-balancer-generated 5XX responses.
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  count = var.create_5xx_alarm_with_terraform ? 1 : 0

  alarm_name          = "${local.name}-target-5xx"
  alarm_description   = "Application targets returned one or more HTTP 5XX responses."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
    TargetGroup  = aws_lb_target_group.application.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  depends_on = [aws_sns_topic_policy.alerts]
}

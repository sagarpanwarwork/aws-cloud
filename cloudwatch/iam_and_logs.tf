resource "aws_iam_role" "instance" {
  name               = "${local.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.instance.name
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/zeron-academy/${local.name}/application"
  retention_in_days = 3

  tags = {
    Name = "/zeron-academy/${local.name}/application"
  }
}

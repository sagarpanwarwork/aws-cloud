terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4, < 3.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# ---------------------------------------------------------
# 1. Package the Python code into a ZIP file
# ---------------------------------------------------------
# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   output_path = "${path.module}/lambda-run-hello.zip"

#   source {
#     filename = "lambda_function.py"

#     content = <<-PYTHON
#       import json

#       def lambda_handler(event, context):
#           name = event.get("name", "student")

#           message = f"Hello, {name}! This response came from AWS Lambda."

#           print(json.dumps({
#               "requestId": context.aws_request_id,
#               "functionName": context.function_name,
#               "eventName": name
#           }))

#           return {
#               "statusCode": 200,
#               "body": json.dumps({
#                   "message": message,
#                   "function": context.function_name
#               })
#           }
#     PYTHON
#   }
# }

# Package the separate Python source file into a ZIP
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda-run-hello.zip"

  source {
    filename = "lambda_function.py"
    content  = file("${path.module}/lambda_function.py")
  }
}

# ---------------------------------------------------------
# 2. Define who can assume the Lambda execution role
# ---------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------
# 3. Create the Lambda execution role
# ---------------------------------------------------------
resource "aws_iam_role" "lambda_exec" {
  name               = "role-lambda-run-hello"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "role-lambda-run-hello"
  }
}

# Grant basic permissions for CloudWatch logging
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role = aws_iam_role.lambda_exec.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---------------------------------------------------------
# 4. Create a CloudWatch log group
# ---------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/lambda-run-hello"
  retention_in_days = 7
}

# ---------------------------------------------------------
# 5. Create the Lambda function
# ---------------------------------------------------------
resource "aws_lambda_function" "hello" {
  function_name = "lambda-run-hello"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role    = aws_iam_role.lambda_exec.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  architectures = ["x86_64"]

  memory_size = 128
  timeout     = 10

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_logs,
    aws_cloudwatch_log_group.lambda
  ]

  tags = {
    Name = "lambda-run-hello"
  }
}

# ---------------------------------------------------------
# 6. Outputs
# ---------------------------------------------------------
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.hello.function_name
}

output "lambda_log_group" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

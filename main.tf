terraform {
  required_version = ">= 1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_vpc" "custom_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "piroz-vpc"
  }
}

# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "custom_vpc_flow_logs" {
  name = "custom_vpc_flow_logs"
}

data "aws_iam_policy_document" "assume_vpc_flow_logs" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "custom_vpc_flow_logs" {
  name               = "custom_vpc_flow_logs"
  assume_role_policy = data.aws_iam_policy_document.assume_vpc_flow_logs.json
}

data "aws_iam_policy_document" "allow_logs" {

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = [
      aws_cloudwatch_log_group.custom_vpc_flow_logs.arn
    ]
  }
}

resource "aws_iam_policy" "allow_logs" {
  name   = "allow_logs"
  policy = data.aws_iam_policy_document.allow_logs.json
}

resource "aws_iam_role_policy_attachment" "allow_logs" {
  role       = aws_iam_role.custom_vpc_flow_logs.name
  policy_arn = aws_iam_policy.allow_logs.arn
}

resource "aws_flow_log" "custom_vpc" {
  iam_role_arn    = aws_iam_role.custom_vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.custom_vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.custom_vpc.id
}

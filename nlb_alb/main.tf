locals {
  # When we're validating the terraform we aren't in the same relative
  # location to the lambda so we allow an override
  lambda_path = var.lambda_path != "" ? var.lambda_path : "${path.module}/lambda.zip"
  lambda_name = "${local.name_prefix}-nlb-alb"
  name_prefix = var.name_prefix != "" ? var.name_prefix : terraform.workspace
  log_group_name = "/aws/lambda/${local.lambda_name}"

}

resource "aws_lambda_function" "nlb_alb" {
  description      = "Function for keeping an NLB up to date with ALB"
  filename         = local.lambda_path
  function_name    = local.lambda_name
  role             = aws_iam_role.nlb_alb_lambda.arn
  handler          = "populate_NLB_TG_with_ALB.lambda_handler"
  source_code_hash = filebase64sha256(local.lambda_path)
  runtime          = "python3.9"
  memory_size      = 128
  timeout          = 30

  tags = local.tags

  vpc_config {
    subnet_ids         = data.aws_lb.alb.subnets
    security_group_ids = [module.lambda_out_sg.security_group_id]
  }
  environment {
    variables = {
      ALB_DNS_NAME = data.aws_lb.alb.dns_name
      ALB_LISTENER = var.alb_listener_port
      S3_BUCKET = var.runtime_config_bucket
      NLB_TG_ARN = data.aws_lb_listener.nlb_default_listener.default_action[0].target_group_arn
      MAX_LOOKUP_PER_INVOCATION = 50 # The max times of DNS look per invocation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                46q`,
      INVOCATIONS_BEFORE_DEREGISTRATION = 3 #The number of required Invocations before an IP address is deregistered.
      CW_METRIC_FLAG_IP_COUNT = "true" #The controller flag that enables the CloudWatch metric of the IP address count.
    }

  }
}

resource "aws_iam_role" "nlb_alb_lambda" {
  name =   "${local.lambda_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "nlb_alb_lambda" {
  name = aws_iam_role.nlb_alb_lambda.name
  role = aws_iam_role.nlb_alb_lambda.id
  policy = data.aws_iam_policy_document.nlb_alb_lambda.json
}

resource "aws_iam_role_policy_attachment" "vpc_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role = aws_iam_role.nlb_alb_lambda.id
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "nlb_alb_lambda" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
    sid = "LambdaLogging"
  }

  statement {
    actions = [
      "s3:Get*",
      "s3:PutObject"
    ]
    resources = [
      data.aws_s3_bucket.config_bucket.arn,
      "${data.aws_s3_bucket.config_bucket.arn}/*"
    ]
    sid = "s3"
  }

  statement {
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["*"]
    sid = "ELB"
  }

  statement {
    actions = [
      "cloudwatch:putMetricData"
    ]
    resources = ["*"]
    sid = "CW"
  }
}


module "lambda_out_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = local.lambda_name
  description = "Security group to allow communication with AWS api."
  vpc_id      = var.vpc_id

  egress_with_cidr_blocks= [
    {
      rule = "https-443-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_cloudwatch_event_rule" "nlb_alb" {
  name        = local.lambda_name
  description = "triggers sync between nlb and alb ips"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "synthetic_transaction" {
  rule      = aws_cloudwatch_event_rule.nlb_alb.name
  target_id = "${local.lambda_name}-periodic"
  arn       = aws_lambda_function.nlb_alb.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nlb_alb.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.nlb_alb.arn
}


resource "aws_cloudwatch_log_group" "synthetic_transaction" {
  name              = local.log_group_name
  retention_in_days = 7
}
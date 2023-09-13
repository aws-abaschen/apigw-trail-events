resource "aws_cloudwatch_log_group" "trail" {
  name = "${var.log_group_prefix}/write-mgt-events-trail"
}

data "aws_iam_policy_document" "cloudtrail_inline_policy" {
  statement {
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.trail.name}:log-stream:*",
    ]
  }
}
resource "aws_iam_role" "trail-cloudwatch" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_cloudtrail.json

  inline_policy {
    name   = "policy_log_group"
    policy = data.aws_iam_policy_document.cloudtrail_inline_policy.json
  }
}

resource "aws_s3_bucket" "api-gateway-trail" {
  bucket        = "api-gateway-trail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

data "aws_iam_policy_document" "api-gateway-trail" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.api-gateway-trail.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.api-gateway-trail.arn}/${var.trail_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"]
    }
  }
}
resource "aws_s3_bucket_policy" "api-gateway-trail" {
  bucket = aws_s3_bucket.api-gateway-trail.id
  policy = data.aws_iam_policy_document.api-gateway-trail.json
}

resource "aws_cloudtrail" "only_management" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.api-gateway-trail.id
  include_global_service_events = true
  enable_logging                = true
  s3_key_prefix                 = var.trail_prefix
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail-cloudwatch.arn
  event_selector {
    read_write_type                  = "WriteOnly"
    include_management_events        = true
    exclude_management_event_sources = ["kms.amazonaws.com", "rdsdata.amazonaws.com"]
  }
}


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.mjs"
  output_path = "build/lambda_function_payload.zip"
}

resource "aws_cloudwatch_log_group" "api_trail_events" {
  name = "${var.log_group_prefix}/${var.log_group__api_trail_events}"
}

resource "aws_lambda_function" "trail_event_to_log_stream" {
  filename         = data.archive_file.lambda.output_path
  function_name    = var.lambda__trail_event_to_log_stream__name
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "lambda.handler"
  source_code_hash = md5(file(data.archive_file.lambda.source_file))
  environment {
    variables = {
      LOG_GROUP_NAME = aws_cloudwatch_log_group.api_trail_events.name
    }
  }
  runtime = "nodejs18.x"
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs
  ]
}

data "aws_iam_policy_document" "lambda_logging" {
  // Lambda logs
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda__trail_event_to_log_stream__name}:*"
    ]
  }

  // API Gateway trail logging
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.api_trail_events.name}:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging API Gateway trail events from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

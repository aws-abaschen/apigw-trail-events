resource "aws_cloudwatch_log_group" "trail" {
  name = "write-mgt-events-trail"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name = "/aws/lambda/deployment_events"
}

data "aws_iam_policy_document" "cloudtrail_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}
locals {
  trail_name   = "poc_mgt_trail"
  trail_prefix = "prefix"
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
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role_policy.json

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
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
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
    resources = ["${aws_s3_bucket.api-gateway-trail.arn}/${local.trail_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }
}
resource "aws_s3_bucket_policy" "api-gateway-trail" {
  bucket = aws_s3_bucket.api-gateway-trail.id
  policy = data.aws_iam_policy_document.api-gateway-trail.json
}

resource "aws_cloudtrail" "only_management" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.api-gateway-trail.id
  include_global_service_events = true
  enable_logging                = true
  s3_key_prefix                 = local.trail_prefix
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail-cloudwatch.arn
  event_selector {
    read_write_type                  = "WriteOnly"
    include_management_events        = true
    exclude_management_event_sources = ["kms.amazonaws.com", "rdsdata.amazonaws.com"]
  }
}

resource "aws_lambda_permission" "trail_invoke_echo" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.echo_event.arn
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
}
resource "aws_cloudwatch_log_subscription_filter" "test_lambdafunction_logfilter" {
  name = "fn-api-event-trail"
  //role_arn        = aws_iam_role.iam_for_lambda.arn
  log_group_name  = aws_cloudwatch_log_group.trail.name
  filter_pattern  = "{($.eventSource = \"apigateway.amazonaws.com\" && $.requestParameters.restApiId = \"${aws_api_gateway_rest_api.api.id}\") && ($.eventName = \"CreateDeployment\")}"
  destination_arn = aws_lambda_function.echo_event.arn
  depends_on      = [aws_lambda_permission.trail_invoke_echo]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.mjs"
  output_path = "build/lambda_function_payload.zip"
}

resource "aws_lambda_function" "echo_event" {
  filename      = data.archive_file.lambda.output_path
  function_name = "echo_event"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"
  source_code_hash = md5(file(data.archive_file.lambda.source_file))

  runtime = "nodejs18.x"
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "aws_iam_policy_document" "lambda_queryapigw" {
  statement {
    effect = "Allow"
    actions = ["apigateway:GET"]

    resources = [
      "arn:aws:apigateway:*::/apis/*/routes/*",
      "arn:aws:apigateway:*::/domainnames/*/apimappings",
      "arn:aws:apigateway:*::/apis/*/deployments",
      "arn:aws:apigateway:*::/apis/*/deployments/*"
    ]
  }
}

resource "aws_iam_policy" "lambda_queryapigw" {
  name        = "lambda_queryapigw"
  path        = "/"
  description = "IAM policy for querying deployment from a lambda"
  policy      = data.aws_iam_policy_document.lambda_queryapigw.json
}
resource "aws_iam_role_policy_attachment" "lambda_queryapigw" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_queryapigw.arn
}
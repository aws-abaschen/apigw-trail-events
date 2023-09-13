
data "aws_iam_policy_document" "lambda_queryapigw" {
  statement {
    effect  = "Allow"
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

resource "aws_lambda_permission" "trail_invoke_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trail_event_to_log_stream.arn
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
}
resource "aws_cloudwatch_log_subscription_filter" "test_lambdafunction_logfilter" {
  name = "fn-api-event-trail"
  //role_arn        = aws_iam_role.iam_for_lambda.arn
  log_group_name  = aws_cloudwatch_log_group.trail.name
  filter_pattern  = "{$.eventSource = \"apigateway.amazonaws.com\"}"
  destination_arn = aws_lambda_function.trail_event_to_log_stream.arn
  depends_on      = [aws_lambda_permission.trail_invoke_lambda]
}

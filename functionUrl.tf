resource "aws_cloudwatch_log_subscription_filter" "lambda_functionUrl" {
  name            = "fn-functionUrl-event-trail"
  log_group_name  = aws_cloudwatch_log_group.trail.name
  filter_pattern  = "{$.eventSource = \"lambda.amazonaws.com\" && ($.eventName=\"CreateFunctionUrlConfig\" || $.eventName=\"UpdateFunctionUrlConfig\" || $.eventName=\"DeleteFunctionUrlConfig\")}"
  destination_arn = aws_lambda_function.trail_event_to_log_stream.arn
  depends_on      = [aws_lambda_permission.trail_invoke_lambda]
}


resource "aws_iam_role" "iam_for_echo_lambda" {
  name               = "iam_for_echo_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

data "archive_file" "lambda_echo" {
  type        = "zip"
  source_file = "echo.mjs"
  output_path = "build/echo.zip"
}

resource "aws_lambda_function" "echo" {
  filename         = data.archive_file.lambda_echo.output_path
  function_name    = "testEchoFunctionUrl"
  role             = aws_iam_role.iam_for_echo_lambda.arn
  handler          = "echo.handler"
  source_code_hash = md5(file(data.archive_file.lambda_echo.source_file))
  runtime          = "nodejs18.x"
}


resource "aws_cloudwatch_log_stream" "echofunction_stream" {
  name           = aws_lambda_function.echo.function_name
  log_group_name = aws_cloudwatch_log_group.api_trail_events.name
}

resource "aws_lambda_function_url" "echo_latest" {
  depends_on         = [aws_cloudwatch_log_subscription_filter.lambda_functionUrl, aws_cloudwatch_log_stream.echofunction_stream]
  function_name      = aws_lambda_function.echo.function_name
  authorization_type = "NONE"
}

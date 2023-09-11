

output "trail_log_group_output" {
  value = aws_cloudwatch_log_group.trail.name
}

output "lambda_log_group_output" {
  value = "/aws/lambda/${aws_lambda_function.trail_event_to_log_stream.function_name}"
}

output "api_log_trails_output" {
  value = aws_cloudwatch_log_stream.api_stream.log_group_name
}

output "poc_result_output" {
  value = "${aws_cloudwatch_log_stream.api_stream.log_group_name}/${aws_cloudwatch_log_stream.api_stream.name}"
}
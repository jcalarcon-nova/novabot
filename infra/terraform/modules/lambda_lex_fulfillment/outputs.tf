output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.lex_fulfillment.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.lex_fulfillment.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.lex_fulfillment.invoke_arn
}

output "function_version" {
  description = "Version of the Lambda function"
  value       = aws_lambda_function.lex_fulfillment.version
}

output "alias_arn" {
  description = "ARN of the Lambda function alias"
  value       = aws_lambda_alias.lex_live.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lex_logs.name
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.lex_dlq.arn
}

output "dlq_name" {
  description = "Name of the dead letter queue"
  value       = aws_sqs_queue.lex_dlq.name
}
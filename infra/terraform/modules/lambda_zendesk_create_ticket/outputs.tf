output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.zendesk_create_ticket.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.zendesk_create_ticket.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.zendesk_create_ticket.invoke_arn
}

output "function_version" {
  description = "Version of the Lambda function"
  value       = aws_lambda_function.zendesk_create_ticket.version
}

output "alias_arn" {
  description = "ARN of the Lambda function alias"
  value       = aws_lambda_alias.zendesk_live.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.zendesk_logs.name
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.zendesk_dlq.arn
}

output "dlq_name" {
  description = "Name of the dead letter queue"
  value       = aws_sqs_queue.zendesk_dlq.name
}
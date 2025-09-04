output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.invoke_agent.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.invoke_agent.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.invoke_agent.invoke_arn
}

output "function_version" {
  description = "Version of the Lambda function"
  value       = aws_lambda_function.invoke_agent.version
}

output "alias_arn" {
  description = "ARN of the Lambda function alias"
  value       = aws_lambda_alias.invoke_agent_live.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.invoke_agent_logs.name
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.invoke_agent_dlq.arn
}

output "dlq_name" {
  description = "Name of the dead letter queue"
  value       = aws_sqs_queue.invoke_agent_dlq.name
}
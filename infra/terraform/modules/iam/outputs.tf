output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "bedrock_invoke_role_arn" {
  description = "ARN of the Bedrock invoke role"
  value       = aws_iam_role.bedrock_invoke_role.arn
}

output "bedrock_agent_role_arn" {
  description = "ARN of the Bedrock agent execution role"
  value       = aws_iam_role.bedrock_agent_role.arn
}

output "knowledge_base_role_arn" {
  description = "ARN of the Knowledge Base role"
  value       = aws_iam_role.knowledge_base_role.arn
}

output "zendesk_secret_arn" {
  description = "ARN of the Zendesk credentials secret"
  value       = aws_secretsmanager_secret.zendesk_credentials.arn
  sensitive   = true
}

output "zendesk_secret_name" {
  description = "Name of the Zendesk credentials secret"
  value       = aws_secretsmanager_secret.zendesk_credentials.name
  sensitive   = true
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.novabot_key.arn
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.novabot_key.key_id
}
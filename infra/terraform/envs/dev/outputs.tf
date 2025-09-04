output "bedrock_agent_id" {
  description = "Bedrock agent ID"
  value       = module.bedrock_agent.agent_id
}

output "bedrock_agent_alias_id" {
  description = "Bedrock agent alias ID" 
  value       = module.bedrock_agent.agent_alias_id
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.invoke_url
}

output "knowledge_base_id" {
  description = "Bedrock knowledge base ID"
  value       = module.knowledge_base.knowledge_base_id
}

output "s3_knowledge_base_bucket" {
  description = "S3 bucket for knowledge base data"
  value       = module.knowledge_base.s3_bucket_name
}

output "zendesk_lambda_function_name" {
  description = "Zendesk Lambda function name"
  value       = module.lambda_zendesk.function_name
}

output "lex_lambda_function_name" {
  description = "Lex Lambda function name"
  value       = module.lambda_lex.function_name
}

output "invoke_agent_lambda_function_name" {
  description = "Invoke agent Lambda function name"
  value       = module.lambda_invoke_agent.function_name
}

output "secrets_manager_zendesk_secret_arn" {
  description = "Secrets Manager ARN for Zendesk credentials"
  value       = module.iam.zendesk_secret_arn
  sensitive   = true
}
output "agent_id" {
  description = "ID of the Bedrock agent"
  value       = aws_bedrockagent_agent.novabot_agent.id
}

output "agent_arn" {
  description = "ARN of the Bedrock agent"
  value       = aws_bedrockagent_agent.novabot_agent.agent_arn
}

output "agent_name" {
  description = "Name of the Bedrock agent"
  value       = aws_bedrockagent_agent.novabot_agent.agent_name
}

output "agent_alias_id" {
  description = "ID of the agent alias"
  value       = aws_bedrockagent_agent_alias.novabot_agent_alias.agent_alias_id
}

output "agent_alias_arn" {
  description = "ARN of the agent alias"
  value       = aws_bedrockagent_agent_alias.novabot_agent_alias.agent_alias_arn
}

output "knowledge_base_association_id" {
  description = "ID of the knowledge base association"
  value       = aws_bedrockagent_agent_knowledge_base_association.novabot_kb_association.id
}

output "zendesk_action_group_id" {
  description = "ID of the Zendesk action group"
  value       = aws_bedrockagent_agent_action_group.zendesk_action_group.action_group_id
}

output "schema_s3_bucket" {
  description = "S3 bucket name containing OpenAPI schemas"
  value       = aws_s3_bucket.agent_schemas.bucket
}

output "schema_s3_bucket_arn" {
  description = "ARN of the S3 bucket containing OpenAPI schemas"
  value       = aws_s3_bucket.agent_schemas.arn
}

output "zendesk_schema_s3_key" {
  description = "S3 key for the Zendesk OpenAPI schema"
  value       = aws_s3_object.zendesk_schema.key
}
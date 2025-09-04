output "knowledge_base_id" {
  description = "ID of the Bedrock knowledge base"
  value       = aws_bedrockagent_knowledge_base.novabot_kb.id
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock knowledge base"
  value       = aws_bedrockagent_knowledge_base.novabot_kb.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for knowledge base data"
  value       = aws_s3_bucket.knowledge_base.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for knowledge base data"
  value       = aws_s3_bucket.knowledge_base.arn
}

output "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.knowledge_base.arn
}

output "web_docs_data_source_id" {
  description = "ID of the web docs data source"
  value       = aws_bedrockagent_data_source.web_docs.data_source_id
}

output "curated_articles_data_source_id" {
  description = "ID of the curated articles data source"
  value       = aws_bedrockagent_data_source.curated_articles.data_source_id
}
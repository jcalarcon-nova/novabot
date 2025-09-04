variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "novabot"
}

variable "zendesk_subdomain" {
  description = "Zendesk subdomain for API calls"
  type        = string
  sensitive   = true
}

variable "bedrock_agent_model" {
  description = "Bedrock model for the agent"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "knowledge_base_s3_bucket" {
  description = "S3 bucket name for knowledge base data"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
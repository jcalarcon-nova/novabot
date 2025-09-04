variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "bedrock_agent_model" {
  description = "Bedrock foundation model for the agent"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "knowledge_base_id" {
  description = "ID of the Bedrock knowledge base"
  type        = string
}

variable "zendesk_lambda_function_arn" {
  description = "ARN of the Zendesk Lambda function"
  type        = string
}

variable "bedrock_agent_role_arn" {
  description = "ARN of the IAM role for Bedrock agent execution"
  type        = string
}

variable "agent_instruction" {
  description = "Instruction text for the Bedrock agent"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
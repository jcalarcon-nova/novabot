variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the IAM role for the Lambda function"
  type        = string
}

variable "bedrock_agent_id" {
  description = "ID of the Bedrock agent"
  type        = string
  default     = ""
}

variable "bedrock_agent_alias_id" {
  description = "Alias ID of the Bedrock agent"
  type        = string
  default     = ""
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
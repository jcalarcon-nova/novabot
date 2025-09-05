variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
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

variable "api_domain_name" {
  description = "Custom domain name for the API Gateway"
  type        = string
  default     = "api-novabot.dev.nova-aicoe.com"
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for the custom domain"
  type        = string
  default     = ""
}

variable "enable_custom_domain" {
  description = "Whether to enable custom domain for API Gateway"
  type        = bool
  default     = false
}

variable "root_domain_name" {
  description = "Root domain name (e.g., nova-aicoe.com)"
  type        = string
  default     = "nova-aicoe.com"
}

variable "create_hosted_zone" {
  description = "Whether to create a new Route 53 hosted zone"
  type        = bool
  default     = false
}

variable "existing_hosted_zone_id" {
  description = "ID of existing Route 53 hosted zone"
  type        = string
  default     = ""
}

variable "create_certificate" {
  description = "Whether to create SSL certificate using ACM"
  type        = bool
  default     = false
}
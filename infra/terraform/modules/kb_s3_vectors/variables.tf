variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "knowledge_base_s3_bucket" {
  description = "S3 bucket name for knowledge base data (empty to auto-generate)"
  type        = string
  default     = ""
}

variable "knowledge_base_role_arn" {
  description = "ARN of the IAM role for the knowledge base"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
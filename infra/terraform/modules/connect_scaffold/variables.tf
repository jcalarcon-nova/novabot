variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "lex_lambda_arn" {
  description = "ARN of the Lex fulfillment Lambda function"
  type        = string
}

variable "enable_connect" {
  description = "Whether to create Amazon Connect resources (future use)"
  type        = bool
  default     = false
}

variable "connect_instance_alias" {
  description = "Alias for the Amazon Connect instance"
  type        = string
  default     = ""
}

variable "connect_directory_id" {
  description = "Directory ID for Amazon Connect (if using existing directory)"
  type        = string
  default     = ""
}

variable "inbound_calls_enabled" {
  description = "Whether to enable inbound calls"
  type        = bool
  default     = true
}

variable "outbound_calls_enabled" {
  description = "Whether to enable outbound calls"
  type        = bool
  default     = false
}

variable "contact_flow_logs_enabled" {
  description = "Whether to enable contact flow logs"
  type        = bool
  default     = true
}

variable "contact_lens_enabled" {
  description = "Whether to enable Contact Lens analytics"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
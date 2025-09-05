variable "domain_name" {
  description = "The domain name for the hosted zone"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "api_gateway_domain_name" {
  description = "The custom domain name for API Gateway"
  type        = string
}

variable "api_gateway_target_domain_name" {
  description = "The target domain name from API Gateway"
  type        = string
}

variable "api_gateway_hosted_zone_id" {
  description = "The hosted zone ID from API Gateway"
  type        = string
}

variable "create_hosted_zone" {
  description = "Whether to create a new hosted zone or use existing"
  type        = bool
  default     = false
}

variable "existing_hosted_zone_id" {
  description = "ID of existing hosted zone (if not creating new one)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
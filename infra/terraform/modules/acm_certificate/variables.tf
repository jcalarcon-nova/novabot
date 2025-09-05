variable "domain_name" {
  description = "The domain name for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names for the certificate"
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "The Route 53 hosted zone ID for DNS validation"
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

variable "validation_timeout" {
  description = "Timeout for certificate validation"
  type        = string
  default     = "10m"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
# =============================================================================
# NovaBot Production Environment Configuration
# =============================================================================
# This file contains configuration for the NovaBot production environment.

# =============================================================================
# AWS Configuration
# =============================================================================
# AWS region where all resources will be deployed
aws_region = "us-east-1"

# Environment identifier (always "prod" for production)
environment = "prod"

# Project name used as prefix for all resources
project_name = "novabot"

# =============================================================================
# Zendesk Integration Configuration
# =============================================================================
# Your Zendesk subdomain (e.g., if your Zendesk URL is https://acme.zendesk.com,
# then your subdomain is "acme")
zendesk_subdomain = "your-zendesk-subdomain"

# Note: Zendesk API credentials are stored in AWS Secrets Manager
# For production, use a dedicated Zendesk account with appropriate permissions
# aws secretsmanager create-secret --name "novabot/prod/zendesk/credentials" \
#   --secret-string '{"email":"support@yourdomain.com","token":"your-production-api-token"}'

# =============================================================================
# Amazon Bedrock Configuration
# =============================================================================
# Bedrock model ID for the agent
# Production recommendations:
bedrock_agent_model = "anthropic.claude-3-sonnet-20240229-v1:0"

# =============================================================================
# S3 Knowledge Base Configuration
# =============================================================================
# S3 bucket name for knowledge base data storage
# For production, consider using a specific bucket name for consistency
# Leave empty to auto-generate: novabot-prod-kb-{random}
knowledge_base_s3_bucket = ""

# =============================================================================
# Domain and SSL Configuration
# =============================================================================
# Custom domain name for the API Gateway
# Production environment uses: api-novabot.prod.nova-aicoe.com
api_domain_name = "api-novabot.prod.nova-aicoe.com"

# Root domain name for SSL certificate creation
root_domain_name = "nova-aicoe.com"

# SSL Certificate Configuration
# Production Recommendation: Use ACM auto-creation for managed certificates
certificate_arn = ""  # Leave empty to auto-create certificate

# Auto-create SSL certificate (RECOMMENDED for production)
create_certificate = true  # Set to true for production SSL certificate

# Enable custom domain (REQUIRED for production)
enable_custom_domain = true  # Should be true for production

# Route 53 Configuration
# Production Recommendation: Use existing hosted zone
create_hosted_zone = false  # Use existing hosted zone

# Existing hosted zone ID for nova-aicoe.com (REQUIRED for production with existing domain)
existing_hosted_zone_id = "Z00929461L4FKZPDEU0D0"

# =============================================================================
# Resource Tagging (Production)
# =============================================================================
# Production tags for proper resource management, cost tracking, and compliance
tags = {
  Owner       = "platform-team"
  CostCenter  = "operations"
  Application = "support-chatbot"
  Environment = "production"
  Project     = "novabot"
  ManagedBy   = "terraform"
  Criticality = "high"
  Compliance  = "soc2"
  Backup      = "required"
}
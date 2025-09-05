# AWS Configuration
aws_region   = "us-east-1"
environment  = "dev"
project_name = "novabot"

# Zendesk Configuration
zendesk_subdomain = "novabot-dev"

# Bedrock Configuration
bedrock_agent_model = "anthropic.claude-3-5-sonnet-20241022-v2:0"

# S3 Configuration (leave empty to auto-generate bucket name)
knowledge_base_s3_bucket = ""

# =============================================================================
# Domain and SSL Configuration
# =============================================================================
# Custom domain name for the API Gateway
api_domain_name = "api-novabot.dev.nova-aicoe.com"

# Root domain name for SSL certificate creation
root_domain_name = "nova-aicoe.com"

# SSL Certificate Configuration
certificate_arn = ""  # Leave empty to auto-create certificate
create_certificate = true  # Set to true to create SSL certificate with ACM

# Custom Domain Configuration
enable_custom_domain = true  # Enable custom domain for API Gateway

# Route 53 Configuration
# Use existing hosted zone (nova-aicoe.com)
create_hosted_zone = false  # Use existing hosted zone

# Existing hosted zone ID for nova-aicoe.com
existing_hosted_zone_id = "Z00929461L4FKZPDEU0D0"

# Additional Tags
tags = {
  Owner       = "novabot-team"
  CostCenter  = "engineering"
  Application = "support-chatbot"
  Environment = "dev"
  Project     = "NovaBot"
  ManagedBy   = "Terraform"
}
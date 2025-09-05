locals {
  agent_name = "${var.project_name}-${var.environment}-support-agent"
  
  default_instruction = <<-EOT
You are NovaBot, a helpful AI assistant for technical support. Your primary role is to:

1. **Answer Questions**: Help users with technical questions about MuleSoft, APIs, integrations, and related technologies.

2. **Knowledge Base**: Use your knowledge base to provide accurate, specific answers about documented procedures, troubleshooting steps, and best practices.

3. **Ticket Creation**: When users need personalized support or have complex issues, help them create support tickets by collecting the necessary information:
   - Their email address
   - A clear subject line
   - Detailed description of the issue
   - Priority level (if specified)
   - Any relevant version information (plugin version, MuleSoft runtime)

4. **Communication Style**: 
   - Be friendly, professional, and helpful
   - Ask clarifying questions when needed
   - Provide step-by-step guidance
   - Acknowledge when you don't know something and offer alternatives

5. **Escalation**: If you cannot resolve an issue with available knowledge, proactively suggest creating a support ticket to connect the user with human experts.

When creating tickets, always collect the required information (email, subject, description) and confirm details with the user before proceeding.
EOT
}

# Bedrock Agent
resource "aws_bedrockagent_agent" "novabot_agent" {
  agent_name              = local.agent_name
  agent_resource_role_arn = var.bedrock_agent_role_arn
  foundation_model        = var.bedrock_agent_model
  instruction             = var.agent_instruction != "" ? var.agent_instruction : local.default_instruction
  
  description = "NovaBot AI assistant for technical support and Zendesk ticket creation"
  
  idle_session_ttl_in_seconds = 1800  # 30 minutes
  
  tags = merge(var.tags, {
    Name = local.agent_name
  })
}

# Knowledge Base Association
resource "aws_bedrockagent_agent_knowledge_base_association" "novabot_kb_association" {
  agent_id                = aws_bedrockagent_agent.novabot_agent.id
  description             = "Association with NovaBot knowledge base"
  knowledge_base_id       = var.knowledge_base_id
  knowledge_base_state    = "ENABLED"
}

# Action Group for Zendesk Ticket Creation
resource "aws_bedrockagent_agent_action_group" "zendesk_action_group" {
  agent_id                    = aws_bedrockagent_agent.novabot_agent.id
  agent_version               = "DRAFT"
  action_group_name           = "ZendeskTicketActions"
  description                 = "Actions for creating and managing Zendesk support tickets"
  action_group_state          = "ENABLED"
  skip_resource_in_use_check  = true
  
  action_group_executor {
    lambda = var.zendesk_lambda_function_arn
  }
  
  api_schema {
    s3 {
      s3_bucket_name = aws_s3_bucket.agent_schemas.bucket
      s3_object_key  = aws_s3_object.zendesk_schema.key
    }
  }

  depends_on = [
    aws_s3_object.zendesk_schema
  ]
}

# S3 bucket for storing OpenAPI schemas
resource "aws_s3_bucket" "agent_schemas" {
  bucket = "${var.project_name}-${var.environment}-agent-schemas-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-agent-schemas"
  })
}

# Random ID for bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "agent_schemas" {
  bucket = aws_s3_bucket.agent_schemas.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "agent_schemas" {
  bucket = aws_s3_bucket.agent_schemas.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "agent_schemas" {
  bucket = aws_s3_bucket.agent_schemas.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload OpenAPI schema to S3
resource "aws_s3_object" "zendesk_schema" {
  bucket      = aws_s3_bucket.agent_schemas.bucket
  key         = "openapi/zendesk.yaml"
  source      = "${path.module}/openapi/zendesk.yaml"
  source_hash = filemd5("${path.module}/openapi/zendesk.yaml")
  content_type = "application/x-yaml"

  tags = merge(var.tags, {
    Name = "zendesk-openapi-schema"
  })
}

# Agent Alias for stable endpoint
resource "aws_bedrockagent_agent_alias" "novabot_agent_alias" {
  agent_alias_name = "PROD"
  agent_id         = aws_bedrockagent_agent.novabot_agent.id
  description      = "Production alias for NovaBot agent"
  
  tags = merge(var.tags, {
    Name = "${local.agent_name}-alias"
  })

  depends_on = [
    aws_bedrockagent_agent_action_group.zendesk_action_group,
    aws_bedrockagent_agent_knowledge_base_association.novabot_kb_association
  ]
}

# Agent preparation is handled automatically by the alias creation

# Data source for current AWS region
data "aws_region" "current" {}
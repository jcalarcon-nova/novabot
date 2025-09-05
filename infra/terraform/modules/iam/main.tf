# Local values for dynamic references
locals {
  zendesk_secret_arn = aws_secretsmanager_secret.zendesk_credentials.arn
}

# KMS Key for encryption
resource "aws_kms_key" "novabot_key" {
  description         = "KMS key for NovaBot encryption"
  enable_key_rotation = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-kms-key"
  })
}

resource "aws_kms_alias" "novabot_key_alias" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.novabot_key.key_id
}

# Secrets Manager for Zendesk credentials with lifecycle management
resource "aws_secretsmanager_secret" "zendesk_credentials" {
  name        = "${var.project_name}-${var.environment}-zendesk-credentials"
  description = "Zendesk API credentials for NovaBot"
  kms_key_id  = aws_kms_key.novabot_key.arn
  
  # Set recovery window to 0 to allow immediate recreation
  recovery_window_in_days = 0

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-zendesk-secret"
  })
  
  lifecycle {
    # Ignore changes to prevent recreation if secret exists
    ignore_changes = [
      recovery_window_in_days
    ]
  }
}

resource "aws_secretsmanager_secret_version" "zendesk_credentials_version" {
  secret_id = aws_secretsmanager_secret.zendesk_credentials.id
  secret_string = jsonencode({
    subdomain                = var.zendesk_subdomain
    email                   = "PLACEHOLDER_EMAIL"
    api_token              = "PLACEHOLDER_TOKEN"
    plugin_version_field_id = "PLACEHOLDER_FIELD_ID"
    mule_runtime_field_id  = "PLACEHOLDER_FIELD_ID"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Lambda execution role for general Lambda functions
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-${var.environment}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-lambda-role"
  })
}

# Lambda execution policy for general Lambda functions
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${var.project_name}-${var.environment}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = local.zendesk_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.novabot_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:*:*:*${var.project_name}-${var.environment}-*"
      }
    ]
  })
}

# Bedrock invoke role for Lambda functions that call Bedrock
resource "aws_iam_role" "bedrock_invoke_role" {
  name = "${var.project_name}-${var.environment}-bedrock-invoke-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bedrock-invoke-role"
  })
}

# Bedrock invoke policy
resource "aws_iam_role_policy" "bedrock_invoke_policy" {
  name = "${var.project_name}-${var.environment}-bedrock-invoke-policy"
  role = aws_iam_role.bedrock_invoke_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:*:*:*${var.project_name}-${var.environment}-*"
      }
    ]
  })
}

# Bedrock agent execution role
resource "aws_iam_role" "bedrock_agent_role" {
  name = "${var.project_name}-${var.environment}-bedrock-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bedrock-agent-role"
  })
}

# Bedrock agent policy
resource "aws_iam_role_policy" "bedrock_agent_policy" {
  name = "${var.project_name}-${var.environment}-bedrock-agent-policy"
  role = aws_iam_role.bedrock_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeAgent",
          "bedrock:GetAgent",
          "bedrock:GetAgentVersion",
          "bedrock:GetAgentAlias"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate",
          "bedrock:GetKnowledgeBase",
          "bedrock:AssociateAgentKnowledgeBase"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail",
          "bedrock:GetGuardrail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:CreateAgentMemory",
          "bedrock:GetAgentMemory",
          "bedrock:UpdateAgentMemory",
          "bedrock:DeleteAgentMemory"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Knowledge base role for S3 access
resource "aws_iam_role" "knowledge_base_role" {
  name = "${var.project_name}-${var.environment}-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-kb-role"
  })
}

# Knowledge base S3 access policy
resource "aws_iam_role_policy" "knowledge_base_s3_policy" {
  name = "${var.project_name}-${var.environment}-kb-s3-policy"
  role = aws_iam_role.knowledge_base_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
}
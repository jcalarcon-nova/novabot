locals {
  bucket_name = var.knowledge_base_s3_bucket != "" ? var.knowledge_base_s3_bucket : "${var.project_name}-${var.environment}-knowledge-base-${random_id.bucket_suffix.hex}"
}

# Random ID for bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for knowledge base data
resource "aws_s3_bucket" "knowledge_base" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-knowledge-base"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id

  rule {
    id     = "knowledge_base_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# IAM role for knowledge base (if not provided)
resource "aws_iam_role" "knowledge_base_role" {
  count = var.knowledge_base_role_arn == "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-kb-role"

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

# IAM policy for knowledge base S3 access
resource "aws_iam_role_policy" "knowledge_base_s3_policy" {
  count = var.knowledge_base_role_arn == "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-kb-s3-policy"
  role  = aws_iam_role.knowledge_base_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.knowledge_base.arn,
          "${aws_s3_bucket.knowledge_base.arn}/*"
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

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "novabot_kb" {
  name     = "${var.project_name}-${var.environment}-knowledge-base"
  role_arn = var.knowledge_base_role_arn != "" ? var.knowledge_base_role_arn : aws_iam_role.knowledge_base_role[0].arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.knowledge_base.arn
      vector_index_name = "bedrock-knowledge-base-default-index"
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-knowledge-base"
  })
}

# OpenSearch Serverless Collection for vectors
resource "aws_opensearchserverless_collection" "knowledge_base" {
  name = "${var.project_name}-${var.environment}-kb-collection"
  type = "VECTORSEARCH"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-kb-collection"
  })
}

# OpenSearch Serverless security policy
resource "aws_opensearchserverless_security_policy" "knowledge_base_encryption" {
  name = "${var.project_name}-${var.environment}-kb-encryption"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource = [
          "collection/${var.project_name}-${var.environment}-kb-collection"
        ]
      }
    ]
    AWSOwnedKey = true
  })
}

# Data access policy for OpenSearch Serverless
resource "aws_opensearchserverless_access_policy" "knowledge_base_data_access" {
  name = "${var.project_name}-${var.environment}-kb-data-access"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${var.project_name}-${var.environment}-kb-collection"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource = [
            "index/${var.project_name}-${var.environment}-kb-collection/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = [
        var.knowledge_base_role_arn != "" ? var.knowledge_base_role_arn : aws_iam_role.knowledge_base_role[0].arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_security_policy" "knowledge_base_network" {
  name = "${var.project_name}-${var.environment}-kb-network"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${var.project_name}-${var.environment}-kb-collection"
          ]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# Data source for CSV files
resource "aws_bedrockagent_data_source" "web_docs" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.novabot_kb.id
  name              = "${var.project_name}-${var.environment}-web-docs"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.knowledge_base.arn
      inclusion_prefixes = ["web_docs.csv"]
    }
  }

  depends_on = [aws_bedrockagent_knowledge_base.novabot_kb]
}

resource "aws_bedrockagent_data_source" "curated_articles" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.novabot_kb.id
  name              = "${var.project_name}-${var.environment}-curated-articles"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.knowledge_base.arn
      inclusion_prefixes = ["curated_articles.csv"]
    }
  }

  depends_on = [aws_bedrockagent_knowledge_base.novabot_kb]
}
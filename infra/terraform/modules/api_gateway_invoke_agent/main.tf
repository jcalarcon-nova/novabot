locals {
  api_name = "${var.project_name}-${var.environment}-chatbot-api"
}

# Data sources
data "aws_region" "current" {}

# REST API Gateway
resource "aws_api_gateway_rest_api" "chatbot_api" {
  name        = local.api_name
  description = "NovaBot Chatbot API for Bedrock agent invocation"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = local.api_name
  })
}

# Root resource
resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "invoke-agent"
}

# POST method for /invoke-agent
resource "aws_api_gateway_method" "invoke_agent_post" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "POST"
  authorization = var.enable_api_key ? "API_KEY" : "NONE"
  api_key_required = var.enable_api_key
}

# OPTIONS method for CORS preflight
resource "aws_api_gateway_method" "invoke_agent_options" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# GET method for health check on root
resource "aws_api_gateway_method" "health_check" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

# Lambda Integration for POST /invoke-agent
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.invoke_agent_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${var.invoke_agent_lambda_function_arn}/invocations"
  timeout_milliseconds    = 29000
}

# CORS Integration for OPTIONS /invoke-agent
resource "aws_api_gateway_integration" "cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.invoke_agent_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# CORS Method Response for OPTIONS
resource "aws_api_gateway_method_response" "cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.invoke_agent_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# CORS Integration Response for OPTIONS
resource "aws_api_gateway_integration_response" "cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.invoke_agent_options.http_method
  status_code = aws_api_gateway_method_response.cors_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'content-type,x-amz-date,authorization,x-api-key,x-amz-security-token,x-amz-user-agent,x-requested-with'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,HEAD,OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = length(var.cors_allowed_origins) > 0 ? "'${var.cors_allowed_origins[0]}'" : "'*'"
  }

  depends_on = [aws_api_gateway_integration.cors_integration]
}

# Health check integration
resource "aws_api_gateway_integration" "health_integration" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  http_method = aws_api_gateway_method.health_check.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${aws_lambda_function.health_check.arn}/invocations"
}

# Simple health check Lambda function
resource "aws_lambda_function" "health_check" {
  filename      = data.archive_file.health_check_zip.output_path
  function_name = "${var.project_name}-${var.environment}-api-health"
  role          = aws_iam_role.health_check_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 3

  source_code_hash = data.archive_file.health_check_zip.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-api-health"
  })
}

# Health check function code
data "archive_file" "health_check_zip" {
  type        = "zip"
  output_path = "${path.module}/health_check.zip"
  source {
    content = <<EOF
exports.handler = async (event) => {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify({
      status: 'healthy',
      environment: process.env.ENVIRONMENT,
      timestamp: new Date().toISOString(),
      version: '1.0.0'
    })
  };
};
EOF
    filename = "index.js"
  }
}

# IAM role for health check Lambda
resource "aws_iam_role" "health_check_role" {
  name = "${var.project_name}-${var.environment}-health-check-role"

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
    Name = "${var.project_name}-${var.environment}-health-check-role"
  })
}

# Basic execution policy for health check Lambda
resource "aws_iam_role_policy_attachment" "health_check_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.health_check_role.name
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_method.invoke_agent_post,
    aws_api_gateway_method.invoke_agent_options,
    aws_api_gateway_method.health_check,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.cors_integration,
    aws_api_gateway_integration.health_integration,
    aws_api_gateway_integration_response.cors_integration_response
  ]

  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.root.id,
      aws_api_gateway_method.invoke_agent_post.id,
      aws_api_gateway_method.invoke_agent_options.id,
      aws_api_gateway_method.health_check.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_integration.cors_integration.id,
      aws_api_gateway_integration.health_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  stage_name    = var.environment

# Throttling is managed via method settings in REST API

# Logging disabled temporarily due to CloudWatch role requirements

  tags = merge(var.tags, {
    Name = "${local.api_name}-${var.environment}"
  })

  depends_on = [aws_cloudwatch_log_group.api_logs]
}

# Method Settings for throttling
resource "aws_api_gateway_method_settings" "api_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
    # Logging disabled temporarily due to CloudWatch role requirements
    metrics_enabled        = true
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = var.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.invoke_agent_lambda_function_arn)[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*"
}

# Lambda permission for health check
resource "aws_lambda_permission" "api_gateway_health_check" {
  statement_id  = "AllowExecutionFromAPIGatewayHealth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_check.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*"
}

# API Key (optional)
resource "aws_api_gateway_api_key" "chatbot_api_key" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.project_name}-${var.environment}-chatbot-key"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-api-key"
  })
}

# Usage Plan (optional)
resource "aws_api_gateway_usage_plan" "chatbot_usage_plan" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.project_name}-${var.environment}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.chatbot_api.id
    stage  = aws_api_gateway_stage.api_stage.stage_name
  }

# Throttling is managed via method settings in REST API

  quota_settings {
    limit  = 10000
    period = "DAY"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-usage-plan"
  })
}

# Usage Plan Key (optional)
resource "aws_api_gateway_usage_plan_key" "chatbot_usage_plan_key" {
  count         = var.enable_api_key ? 1 : 0
  key_id        = aws_api_gateway_api_key.chatbot_api_key[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.chatbot_usage_plan[0].id
}

# Domain Name for custom domain
resource "aws_api_gateway_domain_name" "chatbot_domain" {
  count       = var.enable_custom_domain ? 1 : 0
  domain_name = var.domain_name
  
  regional_certificate_arn = var.certificate_arn
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# Base Path Mapping for custom domain
resource "aws_api_gateway_base_path_mapping" "chatbot_mapping" {
  count       = var.enable_custom_domain ? 1 : 0
  api_id      = aws_api_gateway_rest_api.chatbot_api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  domain_name = aws_api_gateway_domain_name.chatbot_domain[0].domain_name
}

# WAF Web ACL (optional)
resource "aws_wafv2_web_acl" "chatbot_waf" {
  count = var.enable_waf ? 1 : 0
  name  = "${var.project_name}-${var.environment}-chatbot-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-waf"
  })

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }
}

# WAF Association (optional)
resource "aws_wafv2_web_acl_association" "chatbot_waf_association" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_api_gateway_stage.api_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.chatbot_waf[0].arn
}
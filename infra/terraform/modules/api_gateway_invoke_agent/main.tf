locals {
  api_name = "${var.project_name}-${var.environment}-chatbot-api"
}

# HTTP API Gateway
resource "aws_apigatewayv2_api" "chatbot_api" {
  name          = local.api_name
  protocol_type = "HTTP"
  description   = "NovaBot Chatbot API for Bedrock agent invocation"

  cors_configuration {
    allow_credentials = false
    allow_headers = [
      "content-type",
      "x-amz-date",
      "authorization",
      "x-api-key",
      "x-amz-security-token",
      "x-amz-user-agent",
      "x-requested-with"
    ]
    allow_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "POST"
    ]
    allow_origins = var.cors_allowed_origins
    expose_headers = [
      "x-amzn-requestid",
      "x-amz-apigw-id"
    ]
    max_age = 300
  }

  tags = merge(var.tags, {
    Name = local.api_name
  })
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                    = aws_apigatewayv2_api.chatbot_api.id
  integration_type          = "AWS_PROXY"
  integration_method        = "POST"
  integration_uri           = var.invoke_agent_lambda_function_arn
  payload_format_version    = "2.0"
  timeout_milliseconds      = 29000  # Max timeout for Lambda

  request_parameters = {}
}

# Routes
resource "aws_apigatewayv2_route" "invoke_agent_post" {
  api_id    = aws_apigatewayv2_api.chatbot_api.id
  route_key = "POST /invoke-agent"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

  authorization_type = var.enable_api_key ? "API_KEY" : "NONE"
}

resource "aws_apigatewayv2_route" "invoke_agent_options" {
  api_id    = aws_apigatewayv2_api.chatbot_api.id
  route_key = "OPTIONS /invoke-agent"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Root route for health check
resource "aws_apigatewayv2_route" "health_check" {
  api_id    = aws_apigatewayv2_api.chatbot_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.health_integration.id}"
}

# Health check integration (simple Lambda response)
resource "aws_apigatewayv2_integration" "health_integration" {
  api_id             = aws_apigatewayv2_api.chatbot_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.health_check.invoke_arn
  payload_format_version = "2.0"
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

# API Gateway Stage
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.chatbot_api.id
  name        = var.environment
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      requestTime   = "$context.requestTime"
      httpMethod    = "$context.httpMethod"
      routeKey      = "$context.routeKey"
      status        = "$context.status"
      protocol      = "$context.protocol"
      responseLength = "$context.responseLength"
      error         = "$context.error.message"
      integrationError = "$context.integration.error"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.api_name}-${var.environment}"
  })

  depends_on = [aws_cloudwatch_log_group.api_logs]
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
  source_arn    = "${aws_apigatewayv2_api.chatbot_api.execution_arn}/*/*"
}

# Lambda permission for health check
resource "aws_lambda_permission" "api_gateway_health_check" {
  statement_id  = "AllowExecutionFromAPIGatewayHealth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_check.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chatbot_api.execution_arn}/*/*"
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
    api_id = aws_apigatewayv2_api.chatbot_api.id
    stage  = aws_apigatewayv2_stage.api_stage.name
  }

  throttle_settings {
    burst_limit = var.throttle_burst_limit
    rate_limit  = var.throttle_rate_limit
  }

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
resource "aws_apigatewayv2_domain_name" "chatbot_domain" {
  count       = var.enable_custom_domain ? 1 : 0
  domain_name = var.domain_name
  
  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

# API Mapping for custom domain
resource "aws_apigatewayv2_api_mapping" "chatbot_mapping" {
  count       = var.enable_custom_domain ? 1 : 0
  api_id      = aws_apigatewayv2_api.chatbot_api.id
  domain_name = aws_apigatewayv2_domain_name.chatbot_domain[0].id
  stage       = aws_apigatewayv2_stage.api_stage.id
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
  resource_arn = aws_apigatewayv2_stage.api_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.chatbot_waf[0].arn
}
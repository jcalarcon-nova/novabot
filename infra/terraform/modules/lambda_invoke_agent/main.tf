# Local variables
locals {
  function_name = "${var.project_name}-${var.environment}-invoke-agent"
  lambda_source_path = "${path.root}/../../../../lambda/invoke_agent"
  module_source_path = "${path.module}/src"
}

# Data source to check if Lambda source exists
data "external" "lambda_build_check" {
  program = ["bash", "-c", <<-EOT
    # Check if we have a built TypeScript version
    if [ -d "${local.lambda_source_path}/dist" ]; then
      echo '{"build_exists": "true", "source_type": "typescript"}'
    # Check if we have our module source
    elif [ -f "${local.module_source_path}/index.js" ]; then
      echo '{"build_exists": "true", "source_type": "module"}'
    else
      echo '{"build_exists": "false", "source_type": "placeholder"}'
    fi
  EOT
  ]
}

# Install dependencies for module source
resource "null_resource" "install_dependencies" {
  count = data.external.lambda_build_check.result.source_type == "module" ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      cd ${local.module_source_path}
      npm install --production
    EOT
  }

  triggers = {
    package_json = fileexists("${local.module_source_path}/package.json") ? filemd5("${local.module_source_path}/package.json") : "none"
  }
}

# Create placeholder if source doesn't exist
resource "null_resource" "create_placeholder" {
  count = data.external.lambda_build_check.result.build_exists == "false" ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/placeholder
      cat > ${path.module}/placeholder/index.js << 'EOF'
exports.handler = async (event) => {
  console.log('Placeholder invoke-agent Lambda function');
  console.log('Event:', JSON.stringify(event, null, 2));
  return {
    statusCode: 501,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify({
      error: 'Not Implemented',
      message: 'This is a placeholder. Deploy the actual TypeScript function.'
    })
  };
};
EOF
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

# Build the TypeScript Lambda function
resource "null_resource" "lambda_build" {
  count = data.external.lambda_build_check.result.build_exists == "false" ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      cd ${local.lambda_source_path}
      if [ -f "package.json" ]; then
        npm install
        npm run build
      fi
    EOT
  }

  triggers = {
    package_json = fileexists("${local.lambda_source_path}/package.json") ? filemd5("${local.lambda_source_path}/package.json") : "none"
    source_code  = fileexists("${local.lambda_source_path}/src/index.ts") ? filemd5("${local.lambda_source_path}/src/index.ts") : "none"
  }
}

# Archive Lambda function for deployment
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/invoke_agent.zip"
  
  # Use built files if available, module source, or placeholder
  source_dir = (
    data.external.lambda_build_check.result.source_type == "typescript" ? "${local.lambda_source_path}/dist" :
    data.external.lambda_build_check.result.source_type == "module" ? local.module_source_path :
    "${path.module}/placeholder"
  )
  
  depends_on = [
    null_resource.lambda_build, 
    null_resource.create_placeholder,
    null_resource.install_dependencies
  ]
}

# Lambda function for invoking Bedrock agent
resource "aws_lambda_function" "invoke_agent" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.function_name
  role            = var.lambda_role_arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 300
  memory_size     = 1024

  environment {
    variables = {
      NODE_ENV                = var.environment
      LOG_LEVEL               = var.environment == "prod" ? "info" : "debug"
      BEDROCK_AGENT_ID        = var.bedrock_agent_id
      BEDROCK_AGENT_ALIAS_ID  = var.bedrock_agent_alias_id
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.invoke_agent_dlq.arn
  }

  tags = merge(var.tags, {
    Name = local.function_name
  })

  depends_on = [
    aws_cloudwatch_log_group.invoke_agent_logs,
    null_resource.lambda_build
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "invoke_agent_logs" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = var.tags
}

# Dead Letter Queue for failed invocations
resource "aws_sqs_queue" "invoke_agent_dlq" {
  name                      = "${local.function_name}-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(var.tags, {
    Name = "${local.function_name}-dlq"
  })
}

# Lambda permission for API Gateway to invoke
resource "aws_lambda_permission" "allow_api_gateway" {
  count         = var.api_gateway_execution_arn != "" ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.invoke_agent.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# Current AWS region data
data "aws_region" "current" {}

# Lambda function alias for versioning
resource "aws_lambda_alias" "invoke_agent_live" {
  name             = "live"
  description      = "Live alias for invoke-agent Lambda"
  function_name    = aws_lambda_function.invoke_agent.function_name
  function_version = "$LATEST"

  depends_on = [aws_lambda_function.invoke_agent]
}
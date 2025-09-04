# Local variables
locals {
  function_name = "${var.project_name}-${var.environment}-lex-fulfillment"
  lambda_source_path = "${path.root}/../../lambda/lex_fulfillment"
}

# Data source to check if Lambda source exists
data "external" "lambda_build_check" {
  program = ["bash", "-c", <<-EOT
    if [ -d "${local.lambda_source_path}/dist" ]; then
      echo '{"build_exists": "true"}'
    else
      echo '{"build_exists": "false"}'
    fi
  EOT
  ]
}

# Create placeholder if source doesn't exist
resource "null_resource" "create_placeholder" {
  count = data.external.lambda_build_check.result.build_exists == "false" ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/placeholder
      cat > ${path.module}/placeholder/index.js << 'EOF'
exports.handler = async (event) => {
  console.log('Placeholder Lex fulfillment Lambda function');
  console.log('Event:', JSON.stringify(event, null, 2));
  
  return {
    sessionState: {
      dialogAction: {
        type: 'Close',
        fulfillmentState: 'Fulfilled'
      },
      intent: {
        name: event.interpretations?.[0]?.intent?.name || 'Unknown',
        state: 'Fulfilled'
      }
    },
    messages: [{
      contentType: 'PlainText',
      content: 'This is a placeholder response. The actual Lex fulfillment function needs to be deployed.'
    }]
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
  output_path = "${path.module}/lex_fulfillment.zip"
  
  # Use built files if available, otherwise use placeholder
  source_dir = data.external.lambda_build_check.result.build_exists == "true" ? "${local.lambda_source_path}/dist" : "${path.module}/placeholder"
  
  depends_on = [null_resource.lambda_build, null_resource.create_placeholder]
}

# Lambda function
resource "aws_lambda_function" "lex_fulfillment" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.function_name
  role            = var.lambda_role_arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      NODE_ENV                  = var.environment
      AWS_REGION               = data.aws_region.current.name
      LOG_LEVEL                = var.environment == "prod" ? "info" : "debug"
      BEDROCK_AGENT_ID         = var.bedrock_agent_id
      BEDROCK_AGENT_ALIAS_ID   = var.bedrock_agent_alias_id
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lex_dlq.arn
  }

  tags = merge(var.tags, {
    Name = local.function_name
  })

  depends_on = [
    aws_cloudwatch_log_group.lex_logs,
    null_resource.lambda_build
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lex_logs" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = var.tags
}

# Dead Letter Queue for failed invocations
resource "aws_sqs_queue" "lex_dlq" {
  name                      = "${local.function_name}-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(var.tags, {
    Name = "${local.function_name}-dlq"
  })
}

# Lambda permission for Lex to invoke
resource "aws_lambda_permission" "allow_lex" {
  statement_id  = "AllowExecutionFromLex"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lex_fulfillment.function_name
  principal     = "lexv2.amazonaws.com"
}

# Lambda permission for Connect to invoke
resource "aws_lambda_permission" "allow_connect" {
  statement_id  = "AllowExecutionFromConnect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lex_fulfillment.function_name
  principal     = "connect.amazonaws.com"
}

# Current AWS region data
data "aws_region" "current" {}

# Lambda function alias for versioning
resource "aws_lambda_alias" "lex_live" {
  name             = "live"
  description      = "Live alias for Lex fulfillment Lambda"
  function_name    = aws_lambda_function.lex_fulfillment.function_name
  function_version = "$LATEST"

  depends_on = [aws_lambda_function.lex_fulfillment]
}
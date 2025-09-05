# Local variables
locals {
  function_name = "${var.project_name}-${var.environment}-zendesk-create-ticket"
  lambda_source_path = "${path.root}/../../lambda/zendesk_create_ticket"
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

# Archive Lambda function for deployment
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/zendesk_create_ticket.zip"
  
  # Use built files if available, otherwise use placeholder
  source_dir = data.external.lambda_build_check.result.build_exists == "true" ? "${local.lambda_source_path}/dist" : "${path.module}/placeholder"
  
  depends_on = [null_resource.lambda_build]
}

# Create placeholder if source doesn't exist
resource "null_resource" "create_placeholder" {
  count = data.external.lambda_build_check.result.build_exists == "false" ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/placeholder
      cat > ${path.module}/placeholder/index.js << 'EOF'
exports.handler = async (event) => {
  console.log('Placeholder Zendesk Lambda function');
  console.log('Event:', JSON.stringify(event, null, 2));
  return {
    statusCode: 501,
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

# Lambda function
resource "aws_lambda_function" "zendesk_create_ticket" {
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
      NODE_ENV                = var.environment
      ZENDESK_SECRET_NAME     = split("/", var.zendesk_secret_arn)[6]
      AWS_REGION              = data.aws_region.current.id
      LOG_LEVEL               = var.environment == "prod" ? "info" : "debug"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.zendesk_dlq.arn
  }

  tags = merge(var.tags, {
    Name = local.function_name
  })

  depends_on = [
    aws_cloudwatch_log_group.zendesk_logs,
    null_resource.lambda_build
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "zendesk_logs" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = var.tags
}

# Dead Letter Queue for failed invocations
resource "aws_sqs_queue" "zendesk_dlq" {
  name                      = "${local.function_name}-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(var.tags, {
    Name = "${local.function_name}-dlq"
  })
}

# Lambda permission for Bedrock to invoke
resource "aws_lambda_permission" "allow_bedrock" {
  statement_id  = "AllowExecutionFromBedrock"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.zendesk_create_ticket.function_name
  principal     = "bedrock.amazonaws.com"
}

# Current AWS region data
data "aws_region" "current" {}

# Lambda function alias for versioning
resource "aws_lambda_alias" "zendesk_live" {
  name             = "live"
  description      = "Live alias for Zendesk ticket creation Lambda"
  function_name    = aws_lambda_function.zendesk_create_ticket.function_name
  function_version = "$LATEST"

  depends_on = [aws_lambda_function.zendesk_create_ticket]
}
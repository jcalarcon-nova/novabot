output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.chatbot_api.id
}

output "api_arn" {
  description = "ARN of the API Gateway"
  value       = aws_apigatewayv2_api.chatbot_api.arn
}

output "invoke_url" {
  description = "Invoke URL for the API Gateway"
  value       = aws_apigatewayv2_stage.api_stage.invoke_url
}

output "execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_apigatewayv2_api.chatbot_api.execution_arn
}

output "stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_apigatewayv2_stage.api_stage.name
}

output "invoke_agent_endpoint" {
  description = "Full endpoint URL for invoking the agent"
  value       = "${aws_apigatewayv2_stage.api_stage.invoke_url}/invoke-agent"
}

output "health_check_endpoint" {
  description = "Health check endpoint URL"
  value       = "${aws_apigatewayv2_stage.api_stage.invoke_url}/"
}

output "api_key_id" {
  description = "ID of the API key (if enabled)"
  value       = var.enable_api_key ? aws_api_gateway_api_key.chatbot_api_key[0].id : null
}

output "api_key_value" {
  description = "Value of the API key (if enabled)"
  value       = var.enable_api_key ? aws_api_gateway_api_key.chatbot_api_key[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID of the usage plan (if API key is enabled)"
  value       = var.enable_api_key ? aws_api_gateway_usage_plan.chatbot_usage_plan[0].id : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for API Gateway"
  value       = aws_cloudwatch_log_group.api_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for API Gateway"
  value       = aws_cloudwatch_log_group.api_logs.arn
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL (if enabled)"
  value       = var.enable_waf ? aws_wafv2_web_acl.chatbot_waf[0].arn : null
}

output "health_check_function_name" {
  description = "Name of the health check Lambda function"
  value       = aws_lambda_function.health_check.function_name
}

output "cors_configuration" {
  description = "CORS configuration details"
  value = {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "HEAD", "OPTIONS", "POST"]
    allow_headers = [
      "content-type",
      "x-amz-date",
      "authorization",
      "x-api-key",
      "x-amz-security-token",
      "x-amz-user-agent",
      "x-requested-with"
    ]
  }
}

output "custom_domain_name" {
  description = "Custom domain name (if enabled)"
  value       = var.enable_custom_domain ? var.domain_name : null
}

output "custom_domain_target" {
  description = "Target domain name for custom domain (if enabled)"
  value       = var.enable_custom_domain ? aws_apigatewayv2_domain_name.chatbot_domain[0].domain_name_configuration[0].target_domain_name : null
}
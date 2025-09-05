terraform {
  backend "s3" {
    bucket       = "nova-terraform-state-us-east-1"
    key          = "novabot/prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# IAM and Security Module
module "iam" {
  source = "../../modules/iam"
  
  environment        = var.environment
  project_name       = var.project_name
  zendesk_subdomain  = var.zendesk_subdomain
  tags              = local.common_tags
}

# S3 and Knowledge Base Module
module "knowledge_base" {
  source = "../../modules/kb_s3_vectors"
  
  environment               = var.environment
  project_name              = var.project_name
  knowledge_base_s3_bucket  = var.knowledge_base_s3_bucket
  tags                     = local.common_tags
  
  depends_on = [module.iam]
}

# Lambda Functions
module "lambda_zendesk" {
  source = "../../modules/lambda_zendesk_create_ticket"
  
  environment           = var.environment
  project_name          = var.project_name
  zendesk_secret_arn    = module.iam.zendesk_secret_arn
  lambda_role_arn       = module.iam.lambda_execution_role_arn
  tags                 = local.common_tags
}

module "lambda_lex" {
  source = "../../modules/lambda_lex_fulfillment"
  
  environment        = var.environment
  project_name       = var.project_name
  lambda_role_arn    = module.iam.lambda_execution_role_arn
  tags              = local.common_tags
}

module "lambda_invoke_agent" {
  source = "../../modules/lambda_invoke_agent"
  
  environment        = var.environment
  project_name       = var.project_name
  lambda_role_arn    = module.iam.bedrock_invoke_role_arn
  tags              = local.common_tags
}

# Bedrock Agent
module "bedrock_agent" {
  source = "../../modules/bedrock_agent"
  
  environment                   = var.environment
  project_name                  = var.project_name
  bedrock_agent_model           = var.bedrock_agent_model
  knowledge_base_id             = module.knowledge_base.knowledge_base_id
  zendesk_lambda_function_arn   = module.lambda_zendesk.function_arn
  bedrock_agent_role_arn        = module.iam.bedrock_agent_role_arn
  tags                         = local.common_tags
  
  depends_on = [
    module.knowledge_base,
    module.lambda_zendesk
  ]
}

# API Gateway
module "api_gateway" {
  source = "../../modules/api_gateway_invoke_agent"
  
  environment                      = var.environment
  project_name                     = var.project_name
  invoke_agent_lambda_function_arn = module.lambda_invoke_agent.function_arn
  tags                           = local.common_tags
  
  depends_on = [module.lambda_invoke_agent]
}

# Amazon Connect Scaffold (Optional)
module "connect_scaffold" {
  source = "../../modules/connect_scaffold"
  
  environment           = var.environment
  project_name          = var.project_name
  lex_lambda_arn        = module.lambda_lex.function_arn
  tags                 = local.common_tags
}

# Observability
module "observability" {
  source = "../../modules/observability"
  
  environment                    = var.environment
  project_name                   = var.project_name
  bedrock_agent_id              = module.bedrock_agent.agent_id
  lambda_function_names         = [
    module.lambda_zendesk.function_name,
    module.lambda_lex.function_name,
    module.lambda_invoke_agent.function_name
  ]
  api_gateway_id = module.api_gateway.api_id
  tags          = local.common_tags
}
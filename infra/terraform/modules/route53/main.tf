# Route 53 Hosted Zone (optional - only if creating new)
resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.domain_name}"
  })
}

# Data source for existing hosted zone
data "aws_route53_zone" "existing" {
  count        = var.create_hosted_zone ? 0 : 1
  zone_id      = var.existing_hosted_zone_id
  private_zone = false
}

# Local values to determine which hosted zone to use
locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  hosted_zone_name = var.create_hosted_zone ? aws_route53_zone.main[0].name : data.aws_route53_zone.existing[0].name
}

# A Record for API Gateway custom domain (only if target domain is provided)
resource "aws_route53_record" "api_gateway" {
  count   = var.api_gateway_target_domain_name != "" ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.api_gateway_domain_name
  type    = "A"

  alias {
    name                   = var.api_gateway_target_domain_name
    zone_id                = var.api_gateway_hosted_zone_id
    evaluate_target_health = true
  }
}
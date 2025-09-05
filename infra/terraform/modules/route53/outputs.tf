output "hosted_zone_id" {
  description = "The hosted zone ID"
  value       = local.hosted_zone_id
}

output "hosted_zone_name" {
  description = "The hosted zone name"
  value       = local.hosted_zone_name
}

output "name_servers" {
  description = "The name servers for the hosted zone (if created)"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}

output "api_gateway_record_name" {
  description = "The API Gateway record name"
  value       = length(aws_route53_record.api_gateway) > 0 ? aws_route53_record.api_gateway[0].name : null
}

output "api_gateway_record_fqdn" {
  description = "The API Gateway record FQDN"
  value       = length(aws_route53_record.api_gateway) > 0 ? aws_route53_record.api_gateway[0].fqdn : null
}
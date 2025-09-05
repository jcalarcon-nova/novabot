output "certificate_arn" {
  description = "The ARN of the certificate"
  value       = aws_acm_certificate_validation.cert.certificate_arn
}

output "certificate_domain_validation_options" {
  description = "A list of attributes to feed into other resources to complete certificate validation"
  value       = aws_acm_certificate.cert.domain_validation_options
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = aws_acm_certificate.cert.status
}
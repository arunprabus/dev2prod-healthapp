output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.k3s.arn
}

output "certificate_domain_validation_options" {
  description = "Domain validation options for manual DNS validation"
  value       = aws_acm_certificate.k3s.domain_validation_options
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = aws_acm_certificate.k3s.status
}
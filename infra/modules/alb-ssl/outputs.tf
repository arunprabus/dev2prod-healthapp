output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.k3s_alb.dns_name
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.k3s_cert.arn
}

output "k3s_endpoint" {
  description = "K3s API endpoint with SSL"
  value       = "https://${var.environment}.k3s.${var.domain_name}:443"
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb_sg.id
}
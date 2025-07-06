output "instance_public_ip" {
  description = "Public IP of K3s instance"
  value       = aws_instance.k3s.public_ip
}

output "instance_id" {
  description = "Instance ID of K3s instance"
  value       = aws_instance.k3s.id
}

output "instance_private_ip" {
  description = "Private IP of K3s instance"
  value       = aws_instance.k3s.private_ip
}

output "cluster_endpoint" {
  description = "K3s cluster endpoint"
  value       = "https://${aws_instance.k3s.public_ip}:6443"
}


output "cluster_name" {
  description = "K3s cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "K3s cluster endpoint"
  value       = "https://${aws_instance.k3s_master.public_ip}:6443"
}

output "master_public_ip" {
  description = "Public IP of K3s master node"
  value       = aws_instance.k3s_master.public_ip
}

output "master_private_ip" {
  description = "Private IP of K3s master node"
  value       = aws_instance.k3s_master.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to K3s master"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.k3s_master.public_ip}"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "scp -i ~/.ssh/id_rsa ubuntu@${aws_instance.k3s_master.public_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
}
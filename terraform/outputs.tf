output "control_node_public_ip" {
  description = "Public IP of the Ansible control node"
  value       = aws_instance.control_node.public_ip
}

output "control_node_instance_id" {
  description = "EC2 instance ID of the Ansible control node"
  value       = aws_instance.control_node.id
}

output "managed_nodes_public_ips" {
  description = "List of public IPs of hardening target nodes"
  value       = aws_instance.managed_nodes[*].public_ip
}

output "managed_nodes_instance_ids" {
  description = "List of EC2 instance IDs of hardening target nodes"
  value       = aws_instance.managed_nodes[*].id
}

output "ssh_control_node" {
  description = "Ready-to-paste SSH command to connect to the control node"
  value       = "ssh -i ${pathexpand(var.private_key_path)} ubuntu@${aws_instance.control_node.public_ip}"
}

output "monthly_cost_estimate" {
  description = "Approximate monthly cost at full utilization — stays free under AWS free tier"
  value       = "t3.micro: ~$8.47/month at full utilization (750 h/month free for new accounts). 3 instances = ~$25.41/month if not covered by free tier."
}

variable "aws_region" {
  description = "AWS region where all resources will be provisioned"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Prefix applied to all resource names for easy identification and cost allocation"
  type        = string
  default     = "patching-pipeline"
}

variable "environment" {
  description = "Target environment — controls patch aggressiveness"
  type        = string
  default     = "sandbox"
}

variable "instance_type" {
  description = "EC2 instance type — t3.micro qualifies for AWS free tier (750 h/month)"
  type        = string
  default     = "t3.micro"
}

variable "managed_node_count" {
  description = "Number of EC2 instances that will be patched by the Ansible playbook"
  type        = number
  default     = 2
}

variable "public_key_path" {
  description = "Path to SSH public key uploaded to AWS as a key pair"
  type        = string
  default     = "~/.ssh/ansible-patching-pipeline.pub"
}

variable "private_key_path" {
  description = "Path to SSH private key written into the generated Ansible inventory"
  type        = string
  default     = "~/.ssh/ansible-patching-pipeline"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to reach port 22 — restrict to your IP in production (e.g. 1.2.3.4/32)"
  type        = string
  default     = "0.0.0.0/0"
}

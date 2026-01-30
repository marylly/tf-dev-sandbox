variable "aws_region" {
  description = "AWS region onde a infraestrutura será criada"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo de instância EC2"
  type        = string
  default     = "t3.small"
}

variable "instance_state" {
  description = "Estado desejado da instância (running ou stopped)"
  type        = string
  default     = "running"
  validation {
    condition     = contains(["running", "stopped"], var.instance_state)
    error_message = "instance_state deve ser 'running' ou 'stopped'"
  }
}

variable "my_ip" {
  description = "Seu IP público para acesso SSH (formato CIDR, ex: 203.0.113.0/32)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block para a subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "project_name" {
  description = "Nome do projeto (usado em tags e nomes de recursos)"
  type        = string
  default     = "terraform-dev-sandbox"
}

variable "ssh_public_key_path" {
  description = "Caminho para a chave SSH pública"
  type        = string
  default     = "~/.ssh/terraform-dev.pem.pub"
}

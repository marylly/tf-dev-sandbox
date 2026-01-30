# AWS Region é configurada via config.env (variável AWS_REGION)
# O Makefile passa automaticamente via TF_VAR_aws_region

# Tipo de instância EC2
instance_type = "t3.small"

# Seu IP público para acesso SSH
my_ip = "189.62.46.53/32"

# Nome do projeto (usado em tags)
project_name = "terraform-dev-sandbox"

# Configuração de rede (geralmente não precisa alterar)
vpc_cidr    = "10.0.0.0/16"
subnet_cidr = "10.0.1.0/24"

#!/bin/bash
set -e

# Log de execução
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Iniciando configuração do ambiente Terraform Dev Sandbox ==="
echo "Data/Hora: $(date)"

# Atualizar sistema
echo "Atualizando sistema..."
yum update -y

# Instalar dependências básicas
echo "Instalando dependências básicas..."
yum install -y --allowerasing \
    git \
    make \
    unzip \
    wget \
    curl \
    jq \
    python3 \
    python3-pip \
    rsync

# Instalar tfenv (Terraform version manager)
echo "Instalando tfenv..."
git clone --depth=1 https://github.com/tfutils/tfenv.git /home/ec2-user/.tfenv
chown -R ec2-user:ec2-user /home/ec2-user/.tfenv

# Adicionar tfenv ao PATH
cat >> /home/ec2-user/.bashrc << 'EOF'

# tfenv
export PATH="$HOME/.tfenv/bin:$PATH"
EOF

# Instalar versão padrão do Terraform via tfenv
echo "Instalando Terraform via tfenv..."
su - ec2-user -c "export PATH=\"/home/ec2-user/.tfenv/bin:\$PATH\" && tfenv install latest && tfenv use latest"
su - ec2-user -c "export PATH=\"/home/ec2-user/.tfenv/bin:\$PATH\" && terraform version"

# Instalar tfsec
echo "Instalando tfsec..."
TFSEC_VERSION="1.28.5"
wget -q https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64 -O /usr/local/bin/tfsec
chmod +x /usr/local/bin/tfsec
tfsec --version

# Instalar tflint
echo "Instalando tflint..."
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
tflint --version

# Instalar terraform-docs
echo "Instalando terraform-docs..."
TERRAFORM_DOCS_VERSION="0.17.0"
wget -q https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz
tar -xzf terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz
mv terraform-docs /usr/local/bin/
rm terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz
terraform-docs --version

# Criar diretório de workspace
echo "Criando diretório de workspace..."
mkdir -p /home/ec2-user/workspace
mkdir -p /home/ec2-user/logs
chown -R ec2-user:ec2-user /home/ec2-user/workspace
chown -R ec2-user:ec2-user /home/ec2-user/logs

# Configurar chave SSH pública para testes
echo "Configurando chave SSH pública para testes..."
mkdir -p /home/ec2-user/.ssh
cat /home/ec2-user/.ssh/authorized_keys | head -1 > /home/ec2-user/.ssh/terraform-dev.pem.pub
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh
chmod 644 /home/ec2-user/.ssh/terraform-dev.pem.pub

# Configurar AWS CLI
echo "Configurando AWS CLI..."
pip3 install --upgrade awscli

# Criar arquivo de boas-vindas
cat > /home/ec2-user/README.txt << 'EOF'
=== Terraform Dev Sandbox ===

Este servidor está configurado para desenvolvimento e testes de módulos Terraform.

Ferramentas instaladas:
- tfenv (Terraform version manager)
- Terraform (gerenciado via tfenv)
- tfsec (security scanning)
- tflint (linting)
- terraform-docs (documentação)
- AWS CLI
- Git, Make, Python3

Diretórios:
- ~/workspace/ - Código sincronizado do seu módulo
- ~/logs/ - Logs de execução

Comandos úteis:
- terraform version
- tfenv list (listar versões instaladas)
- tfenv install <version> (instalar versão específica)
- tfenv use <version> (usar versão específica)
- tfsec --version
- tflint --version
- aws sts get-caller-identity

Gerenciamento de versões do Terraform:
- O tfenv detecta automaticamente a versão necessária via:
  1. Arquivo .terraform-version no diretório do módulo
  2. Arquivo versions.tf (required_version)
- Para instalar a versão do módulo atual: cd ~/workspace && tfenv install

Para mais informações, consulte a documentação do projeto.
EOF

chown ec2-user:ec2-user /home/ec2-user/README.txt

echo "=== Configuração concluída com sucesso! ==="
echo "Data/Hora: $(date)"

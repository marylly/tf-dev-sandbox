# Setup - Terraform Dev Sandbox

Guia completo de configuração inicial do ambiente.

## Pré-requisitos

### Sistema Operacional
- macOS (testado em macOS 12+)
- Linux também funciona, mas alguns comandos podem precisar ajustes

### Ferramentas Necessárias
- **AWS CLI** - Para provisionar infraestrutura
- **Terraform** (opcional local) - Será instalado no EC2 via tfenv
- **fswatch** - Para sincronização automática
- **rsync** - Para sincronização de arquivos (geralmente pré-instalado)
- **SSH** - Para conexão com EC2 (pré-instalado)

**Nota**: O EC2 usa tfenv para gerenciar versões do Terraform automaticamente, detectando a versão necessária do seu módulo.

### Conta AWS
- Conta AWS ativa
- Credenciais AWS configuradas (`aws configure`)
- Permissões para criar: VPC, EC2, Security Groups, IAM Roles

## Instalação Passo a Passo

### 1. Clonar o Repositório

```bash
git clone <repo-url> terraform-dev-sandbox
cd terraform-dev-sandbox
```

### 2. Executar Setup Automático

```bash
make setup
```

Este comando irá:
- Verificar dependências (fswatch, rsync, AWS CLI)
- Criar `config.env` a partir do exemplo

### 3. Configurar Variáveis de Ambiente

**Opção 1: Configuração Interativa (Recomendado)**

```bash
make configure
```

Este comando irá:
- Detectar automaticamente seu IP público
- Solicitar o caminho do seu módulo Terraform
- Configurar a região AWS
- Atualizar o arquivo `config.env`

**Opção 2: Configuração Manual**

Edite o arquivo `config.env`:

```bash
vim config.env
```

Configure:

```bash
# Caminho COMPLETO para o módulo Terraform que você vai desenvolver
MODULE_PATH=/Users/seu-usuario/projetos/meu-modulo-terraform

# Região AWS
AWS_REGION=us-east-1

# IP do seu notebook para acesso SSH ao EC2
# Obtenha seu IP em: curl https://ifconfig.me
# Formato: SEU_IP/32
MY_IP=203.0.113.0/32

# Caminho da chave SSH (geralmente não precisa alterar)
SSH_KEY_PATH=~/.ssh/terraform-dev.pem
```

**IMPORTANTE**: Configure `MY_IP` com seu IP público atual. Para obter:
```bash
curl https://ifconfig.me
```

### 4. Configurar infrastructure/terraform.tfvars (Opcional)

Se você não configurou `MY_IP` no `config.env`, ou se quiser sobrescrever outras configurações, edite o arquivo `infrastructure/terraform.tfvars`:

```bash
vim infrastructure/terraform.tfvars
```

**Configurações opcionais**:

```hcl
# IP já configurado via MY_IP no config.env, mas pode sobrescrever aqui
# my_ip = "203.0.113.0/32"

# Outras configurações (opcionais)
# AWS Region é configurada via config.env (AWS_REGION)
instance_type = "t3.small"
project_name  = "terraform-dev-sandbox"
vpc_cidr      = "10.0.0.0/16"
subnet_cidr   = "10.0.1.0/24"
```

**Nota**: O `MY_IP` do `config.env` será usado automaticamente pelo `make provision`. Só configure `my_ip` no `terraform.tfvars` se quiser sobrescrever. O `AWS_REGION` também vem do `config.env`.

### 5. Configurar Credenciais AWS

Se ainda não configurou:

```bash
aws configure
```

Forneça:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (ex: us-east-1)
- Default output format (json)

Verificar:
```bash
aws sts get-caller-identity
```

### 6. Provisionar Infraestrutura

```bash
make provision
```

Este comando irá:
1. Inicializar Terraform
2. Criar VPC, subnet, security group
3. Criar IAM Role para EC2
4. Criar instância EC2
5. Instalar Terraform, tfsec, tflint no EC2

**Tempo estimado**: 3-5 minutos

### 7. Verificar Provisionamento

```bash
make status
```

Deve mostrar:
```
Status do ambiente:
  Módulo: /path/to/seu-modulo
  EC2: Provisionado (54.123.45.67)
  Conexão: OK
```

### 8. Primeira Sincronização

```bash
make sync
```

Sincroniza o código do seu módulo para o EC2.

### 9. Testar Conexão SSH

```bash
make remote-shell
```

Deve abrir um shell no EC2. Teste:
```bash
terraform version
tfsec --version
tflint --version
```

Digite `exit` para sair.

## Configuração Avançada

### Tipo de Instância

Para testes leves, use instância menor:

```hcl
instance_type = "t3.small"  # 2 vCPU, 2GB RAM
```

Para módulos complexos:

```hcl
instance_type = "t3.large"  # 2 vCPU, 8GB RAM
```

### Permissões IAM

Edite `infrastructure/iam.tf` para adicionar permissões necessárias para os providers que você vai testar.

Exemplo para testar módulos AWS completos:

```hcl
Action = [
  "ec2:*",
  "s3:*",
  "rds:*",
  # Adicione conforme necessário
]
```

**Atenção**: Use princípio de menor privilégio em produção.

## Troubleshooting

### Erro: "my_ip" não configurado

```
Error: Missing required argument
```

**Solução**: Configure `my_ip` em `infrastructure/terraform.tfvars`

### Erro: Credenciais AWS inválidas

```
Error: error configuring Terraform AWS Provider
```

**Solução**: Execute `aws configure` e verifique credenciais

### Erro: fswatch não encontrado

```
fswatch: command not found
```

**Solução**: 
```bash
brew install fswatch
```

### Erro: Chave SSH não encontrada

```
Permission denied (publickey)
```

**Solução**: Verifique se a chave existe:
```bash
ls -la ~/.ssh/terraform-dev.pem
chmod 400 ~/.ssh/terraform-dev.pem
```

### EC2 não responde SSH

**Possíveis causas**:
1. Security Group bloqueando seu IP
2. EC2 ainda inicializando (aguarde 2-3 minutos)
3. IP mudou ao reiniciar EC2 (comportamento normal)

**Solução**:
```bash
# Verificar IP atual
make status

# Verificar security group
aws ec2 describe-security-groups --group-ids <SG_ID>

# Atualizar my_ip se mudou
vim infrastructure/terraform.tfvars
make provision
```

## Próximos Passos

Após setup completo:
1. Leia [TESTING.md](TESTING.md) para executar testes
2. Configure seu módulo Terraform
3. Execute `make watch` para sincronização automática
4. Desenvolva e teste!

## Custos Estimados

- EC2 t3.medium: ~$30/mês (on-demand)
- Data transfer: ~$1-5/mês

**Total**: ~$32-35/mês

**Dica**: Use `make stop` quando não estiver usando para economizar.

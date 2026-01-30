# Terraform Dev Sandbox

## Overview
Repositório genérico e reutilizável para criar ambientes de desenvolvimento Terraform com sincronização automática para EC2. Resolve o problema de desenvolver módulos Terraform localmente quando as APIs dos providers estão bloqueadas, permitindo execução de testes remotamente no EC2 com acesso completo às APIs.

## Purpose
Permitir que desenvolvedores:
- Desenvolvam módulos Terraform localmente no notebook
- Sincronizem código automaticamente para EC2 na AWS
- Executem testes (terraform test, tfsec, tflint) remotamente
- Troquem de módulo facilmente via configuração
- Reutilizem a mesma infraestrutura para múltiplos módulos

## Architecture

### Components
1. **Local (Notebook macOS)**
   - Repositório terraform-dev-sandbox (este repo)
   - Módulo Terraform sendo desenvolvido (externo, configurável)
   - Makefile com todos os comandos
   - fswatch + rsync para sincronização

2. **Remote (AWS EC2)**
   - Instância EC2 com Terraform, tfsec, tflint
   - Workspace com código sincronizado
   - `.terraform/` (existe apenas aqui, nunca local)
   - IAM Role para acesso aos providers

3. **Infrastructure (Terraform)**
   - VPC e subnet pública
   - Security Group restritivo (SSH do notebook, HTTPS/HTTP/DNS/NTP de saída)
   - IAM Role e Instance Profile
   - EC2 Instance com user data

### Data Flow
```
Notebook (módulo) → fswatch detecta mudança → rsync sincroniza → EC2 (workspace)
Notebook ← SSH ← Resultados de testes ← EC2
```

## Project Structure

```
terraform-dev-sandbox/
├── infrastructure/           # Terraform para provisionar EC2
│   ├── vpc.tf               # VPC e subnet pública
│   ├── internet-gateway.tf  # Internet Gateway e route table
│   ├── security-group.tf    # Security Group (SSH, HTTPS, HTTP, DNS, NTP)
│   ├── iam.tf               # IAM Role e Instance Profile
│   ├── ec2.tf               # EC2 Instance com user data
│   ├── variables.tf         # Variáveis de entrada (instance_type, my_ip, etc)
│   ├── outputs.tf           # Outputs (ec2_ip, ec2_id, vpc_id, etc)
│   ├── user-data.sh         # Bootstrap do EC2 (instala tfenv, tfsec, tflint)
│   ├── versions.tf          # Versões de providers (AWS, null)
│   ├── terraform.tfvars.example  # Exemplo de variáveis
│   ├── terraform.tfvars     # Variáveis reais (não commitado)
│   ├── .terraform.lock.hcl  # Lock de versões de providers
│   └── tests/               # Testes unitários da infraestrutura (tftest)
│       ├── vpc.tftest.hcl
│       ├── subnet.tftest.hcl
│       ├── internet-gateway.tftest.hcl
│       ├── security-group.tftest.hcl
│       ├── iam.tftest.hcl
│       └── ec2.tftest.hcl
├── docs/
│   ├── SETUP.md             # Configuração detalhada
│   ├── TESTING.md           # Guia de testes (tftest)
│   ├── TROUBLESHOOTING.md   # Resolução de problemas
│   ├── ARCHITECTURE.md      # Detalhes técnicos
│   └── CONTRIBUTING.md      # Guia de contribuição
├── .ai/
│   └── memory/
│       └── codebase.md      # Este arquivo
├── Makefile                 # Todos os comandos
├── config.env               # Configuração (não commitado)
├── config.env.example       # Exemplo de configuração
├── .ai-rules                # Regras para agentes de IA
├── .gitignore
└── README.md                # Quick start minimalista
```

## Key Files

### Makefile
Orquestra todos os comandos do projeto:
- **Setup**: `setup`, `provision`, `start`, `stop`, `destroy`
- **Sync**: `sync`, `watch`
- **Remote**: `remote-shell`, `remote-exec`, `remote-init`, `remote-plan`, `remote-apply`
- **Tests**: `remote-test`, `remote-tfsec`, `remote-lint`, `remote-check`
- **Utils**: `status`, `clean-remote`, `help`

### config.env
Configuração do módulo a desenvolver:
```bash
MODULE_PATH=/path/to/seu-modulo-terraform
AWS_REGION=us-east-1
SSH_KEY_PATH=~/.ssh/terraform-dev.pem
```

### infrastructure/*.tf
Código Terraform organizado por recurso (não monolítico):
- `vpc.tf` - VPC e subnet pública
- `internet-gateway.tf` - Internet Gateway e route table
- `security-group.tf` - Security Group (SSH do notebook, HTTPS/HTTP/DNS/NTP de saída)
- `iam.tf` - IAM Role e Instance Profile para EC2
- `ec2.tf` - EC2 Instance com user data
- `variables.tf` - Variáveis de entrada (instance_type, my_ip, aws_region, etc)
- `outputs.tf` - Outputs (ec2_ip, ec2_id, vpc_id, subnet_id, etc)
- `user-data.sh` - Script de bootstrap (instala tfenv, tfsec, tflint, configura ambiente)
- `versions.tf` - Versões de providers (AWS >= 5.0, null >= 3.0)
- `terraform.tfvars.example` - Exemplo de variáveis para copiar
- `terraform.tfvars` - Variáveis reais (não commitado, criado durante provision)
- `.terraform.lock.hcl` - Lock de versões de providers (commitado)

## Workflows

### Initial Setup
1. Clone: `git clone <repo> terraform-dev-sandbox`
2. Setup: `make setup` (instala fswatch, cria config.env)
3. Configure: `make configure` (configura MODULE_PATH, MY_IP, AWS_REGION interativamente)
4. Provision: `make provision` (cria EC2 com tfenv)
5. Sync: `make sync` (primeira sincronização)
6. Validate: `make remote-check`

### Daily Development
**Option 1: Manual Sync**
1. Desenvolver código no módulo
2. `make sync` quando quiser testar
3. `make remote-check` para validar

**Option 2: Auto Sync (Recomendado)**
1. Terminal 1: `make watch` (sincronização contínua)
2. Terminal 2: Desenvolver normalmente
3. `make remote-check` quando necessário

### Unit Testing with terraform test (tftest)

**Estrutura de Testes**:
```
seu-modulo/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── unit-vpc.tftest.hcl
    ├── unit-security.tftest.hcl
    └── integration.tftest.hcl
```

**Exemplo de Teste**:
```hcl
# tests/unit-vpc.tftest.hcl

# Mock do provider (testes rápidos sem criar recursos)
mock_provider "aws" {
  override_during = apply
}

run "validate_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == var.vpc_cidr
    error_message = "VPC CIDR deve corresponder à variável"
  }
}
```

**Executar Testes**:
```bash
# Sincronizar e executar testes
make remote-test

# Pipeline completo (fmt + validate + lint + tfsec + test)
make remote-check
```

**Fluxo de Execução**:
1. `make remote-test` sincroniza código
2. Executa `terraform init` na pasta `tests/` (instala providers)
3. Executa `terraform test` no diretório raiz
4. Terraform procura `*.tftest.hcl` em `tests/`
5. Executa cada bloco `run` sequencialmente
6. Retorna resultados (passed/failed/skipped)

**Tipos de Testes**:
- **Unit tests**: Validam recursos individuais com mocks
- **Integration tests**: Validam interação entre recursos
- **Plan tests**: Validam o plano sem criar recursos (command = plan)
- **Apply tests**: Criam recursos reais (command = apply, cuidado com custos!)

**Boas Práticas**:
1. Use mocks para testes unitários (rápidos, sem custos)
2. Nomeie testes descritivamente (`should_create_vpc_with_correct_cidr`)
3. Teste casos de sucesso e falha
4. Organize testes por funcionalidade
5. Use variáveis para reutilização

### Switching Modules
1. Editar `config.env` e mudar MODULE_PATH (ou usar `make configure`)
2. `make sync` para sincronizar novo módulo
3. tfenv detecta automaticamente a versão necessária do Terraform
4. Continuar desenvolvimento

Não precisa recriar infraestrutura!

## Technologies

### Core
- **Terraform**: Infraestrutura como código
- **AWS EC2**: Ambiente de execução remoto
- **rsync**: Sincronização incremental de arquivos
- **fswatch**: Monitoramento de mudanças (macOS)

### Testing Tools
- **terraform test (tftest)**: Framework de testes nativo do Terraform (1.6+)
- **tfsec**: Security scanning
- **tflint**: Linting e best practices
- **tfenv**: Gerenciador de versões do Terraform

### Automation
- **Make**: Orquestração de comandos
- **Bash**: Scripts auxiliares

## Design Decisions

### Why Separate Repository?
- Reutilizável para qualquer módulo Terraform
- Não polui o repositório do módulo
- Fácil de atualizar e manter
- Configurável via config.env

### Why rsync + fswatch?
- Simples e confiável
- Incremental (apenas mudanças)
- Disponível nativamente no macOS
- Não requer dependências pesadas

### Why EC2 vs Lambda/Fargate?
- Terraform precisa de ambiente stateful
- `.terraform/` pode ser grande
- Cache de providers persiste
- Debugging interativo mais fácil

### Why One .tf per Resource?
- Fácil localização de código
- Melhor organização
- Facilita code review
- Evita arquivos gigantes

### Why Simple Security?
- Sem Secrets Manager (complexidade desnecessária)
- Sem CloudTrail (mantém custos baixos)
- IAM Role suficiente para credenciais
- SSH keys gerenciadas manualmente

### Why tfenv?
- Gerencia múltiplas versões do Terraform automaticamente
- Detecta versão necessária via `required_version` ou `.terraform-version`
- Instala versão correta automaticamente
- Permite trocar de módulo sem preocupação com versões
- Exemplo: Módulo A usa TF 1.5.0, Módulo B usa TF 1.14.4 - tfenv gerencia automaticamente

### Why Minimal Comments?
- Código deve ser auto-explicativo
- Nomes descritivos > comentários
- Comentários apenas para "por que", não "o que"
- Evita comentários desatualizados
- Reduz ruído visual no código

## Commands Reference

### Setup Commands
```bash
make setup      # Instala fswatch, cria config.env
make configure  # Configura variáveis interativamente (MY_IP auto-detectado, MODULE_PATH, AWS_REGION)
make provision  # Cria infraestrutura EC2 com tfenv (usa AWS_PROFILE, -auto-approve)
make start      # Inicia EC2 (se parado, com -lock-timeout=5m)
make stop       # Para EC2 (mantém infraestrutura, com -lock=false)
make destroy    # Destrói TODA a infraestrutura (sem confirmação, com -lock=false)
```

### Sync Commands
```bash
make sync       # Sincroniza código do módulo uma vez (rsync incremental)
make watch      # Sincronização automática contínua (fswatch + rsync)
```

### Remote Commands
```bash
make remote-shell    # Abre shell SSH no EC2
make remote-exec     # Executa comando customizado no EC2 (use CMD="comando")
make remote-init     # Executa tfenv install min-required && terraform init
make remote-plan     # Executa terraform plan no EC2
make remote-apply    # Executa terraform apply no EC2
make remote-validate # Executa terraform validate no EC2
make remote-fmt      # Executa terraform fmt -recursive no EC2
```

### Test Commands
```bash
# Testes locais do módulo (no notebook do desenvolvedor)
# Nota: pode falhar no macOS com timeout devido a problemas na cadeia de credenciais AWS
# Workaround: use 'make remote-test' para executar testes no EC2
make test            # Executa testes do módulo localmente (com AWS_PROFILE)
make test-verbose    # Testes do módulo com output detalhado (com AWS_PROFILE)

# Testes remotos (módulo do usuário no EC2)
make remote-test     # Sincroniza + executa (cd tests && terraform init) && terraform test
make remote-tfsec    # Sincroniza + executa tfsec (security scanning)
make remote-lint     # Sincroniza + executa tflint (linting)
make remote-check    # Pipeline completo: sync→fmt→validate→lint→tfsec→test
```

**Diferença**:
- `make test`: Testa o módulo do usuário localmente (requer AWS_PROFILE configurado)
- `make remote-test`: Testa o módulo do usuário no EC2

**Limitações de Testes Locais**:
- `make test` pode falhar no macOS com "timeout while waiting for plugin to start"
- Causa: Problemas na cadeia de credenciais AWS (credential chain issues)
- `terraform test` cria múltiplos subprocessos, cada um precisa reinicializar credenciais
- No macOS, isso causa timeouts frequentes
- Solução: Use `make remote-test` - funciona porque o EC2 tem IAM role anexado
- Testes locais requerem AWS_PROFILE configurado corretamente
- Referências oficiais:
  - [HashiCorp: Error timeout while waiting for plugin to start](https://support.hashicorp.com/hc/en-us/articles/18253685000083-Error-timeout-while-waiting-for-plugin-to-start)
  - [HashiCorp: Terraform Run Hanging on macOS](https://support.hashicorp.com/hc/en-us/articles/9790957264915-Terraform-Run-Hanging-or-Timing-out-and-Network-Connection-failure-MacOS)

### Utility Commands
```bash
make status         # Mostra status do ambiente (EC2, conexão, módulo)
make clean          # Limpa arquivos locais do Terraform (.terraform/, *.tfstate*)
make clean-remote   # Limpa arquivos temporários no EC2 (.terraform/, *.tfstate*)
make help           # Mostra todos os comandos disponíveis com descrições
```

## Configuration

### config.env
Todas as variáveis de ambiente do projeto:

```bash
# Caminho para o módulo Terraform que você está desenvolvendo
# Exemplo: MODULE_PATH=/Users/seu-usuario/projetos/meu-modulo-terraform
MODULE_PATH=/path/to/seu-modulo-terraform

# Configurações AWS
# Região onde a infraestrutura será provisionada
AWS_REGION=us-east-1

# IP do seu notebook para acesso SSH ao EC2
# Obtenha seu IP em: curl https://ifconfig.me
# Formato: SEU_IP/32 (CIDR notation)
MY_IP=203.0.113.0/32

# Configurações SSH
# A chave SSH será criada durante o provisionamento
SSH_KEY_PATH=~/.ssh/terraform-dev.pem
```

**Variáveis Detalhadas**:
- `MODULE_PATH`: Caminho absoluto para o módulo Terraform que você está desenvolvendo (externo a este repo)
- `AWS_REGION`: Região AWS onde o EC2 será provisionado (padrão: us-east-1)
- `MY_IP`: Seu IP público em formato CIDR para acesso SSH ao EC2 (detectado automaticamente por `make configure`)
- `SSH_KEY_PATH`: Caminho para a chave SSH privada (criada automaticamente durante `make provision`)

### infrastructure/terraform.tfvars
```hcl
# AWS Region é configurada via config.env (variável AWS_REGION)
# O Makefile passa automaticamente via TF_VAR_aws_region

instance_type = "t3.small"
my_ip         = "203.0.113.0/32"  # Seu IP para SSH
project_name  = "terraform-dev-sandbox"
vpc_cidr      = "10.0.0.0/16"
subnet_cidr   = "10.0.1.0/24"
```

## Troubleshooting

### EC2 não provisionado
```bash
make status  # Verificar status
make provision  # Provisionar se necessário
```

### Erro de conexão SSH
```bash
# Verificar se key existe
ls -la ~/.ssh/terraform-dev.pem

# Verificar permissões
chmod 400 ~/.ssh/terraform-dev.pem

# Testar conexão
ssh -i ~/.ssh/terraform-dev.pem ec2-user@<EC2_IP> echo "ok"
```

### Módulo não encontrado
```bash
# Verificar config.env
cat config.env | grep MODULE_PATH

# Verificar se diretório existe
ls -la $MODULE_PATH
```

### Sincronização não funciona
```bash
# Verificar fswatch instalado
which fswatch

# Instalar se necessário
brew install fswatch

# Testar sincronização manual
make sync
```

### Testes falhando
```bash
# Erro: "Missing required provider"
# Solução: terraform init não foi executado na pasta tests/
make remote-test  # Já faz init automaticamente

# Erro: "Unexpected provider configuration"
# Solução: Conflito entre mock_provider e provider real
# Ajustar testes para usar mock apenas durante apply

# Erro: "No value for required variable"
# Solução: Adicionar bloco variables no teste
run "test_name" {
  variables {
    required_var = "value"
  }
}

# Erro: "timeout while waiting for plugin to start" (macOS)
# Causa: terraform test cria subprocessos que reinicializam credenciais
# Solução: Use make remote-test em vez de make test
# Alternativa: Desabilitar IPv6 no macOS ou usar variáveis de ambiente explícitas
# Referência: https://support.hashicorp.com/hc/en-us/articles/18253685000083

# Ver logs detalhados
make remote-exec CMD="terraform test -verbose"
```

### tfenv não detecta versão
```bash
# Verificar required_version no módulo
make remote-exec CMD="cat versions.tf | grep required_version"

# Instalar versão manualmente
make remote-exec CMD="tfenv install 1.14.4 && tfenv use 1.14.4"

# Listar versões instaladas
make remote-exec CMD="tfenv list"
```

## Cost Estimation
- EC2 t3.small: ~$15/mês (on-demand)
- Data transfer: ~$1-5/mês
- **Total**: ~$16-20/mês

**Optimization**:
- Use spot instances (~70% savings)
- Stop EC2 when not in use (`make stop`)
- Destroy when project ends (`make destroy`)

**Instance Type Considerations**:
- **t3.small** (2 vCPUs, 2 GB RAM): Recomendado para a maioria dos módulos
- **t3.medium** (2 vCPUs, 4 GB RAM): Para módulos muito grandes ou complexos
- **t3.micro** (2 vCPUs, 1 GB RAM): Pode ser lento, não recomendado

## Contributing
See [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md) for contribution guidelines.

## Testing Strategy

### Test Maintenance
- Testes devem ser atualizados sempre que o código muda
- Após qualquer mudança, executar `make test` para validar
- Exemplos de mudanças que requerem atualização de testes:
  - Valores de configuração (instance_type, CIDR, nomes)
  - Adição/remoção de recursos
  - Mudança de comportamento ou lógica
- Testes desatualizados são considerados bugs

### Test Coverage
- 71% de cobertura (10/14 recursos)
- 100% dos recursos críticos testados
- Foco em validação de configuração e segurança

### Gitignore
- Todos os arquivos ignorados pelo git estão centralizados no `.gitignore` da raiz
- Não há arquivos `.gitignore` em subdiretórios

## License
MIT

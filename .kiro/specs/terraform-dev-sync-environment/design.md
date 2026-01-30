# Design: Ambiente de Desenvolvimento Terraform com Sincronização EC2

## 1. Visão Geral da Arquitetura

Este é um repositório genérico e reutilizável para criar ambientes de desenvolvimento Terraform com sincronização EC2.

O sistema consiste em três componentes principais:

1. **Notebook Local (Cliente)**: Onde o código é desenvolvido
2. **Servidor EC2 (Sandbox)**: Onde os testes são executados
3. **Infraestrutura AWS**: Recursos provisionados via Terraform (em pasta separada)

**Importante**: A infraestrutura fica em pasta separada do módulo sendo desenvolvido. Você pode usar este repositório para desenvolver qualquer módulo Terraform, apenas configurando o caminho do módulo.

```
┌─────────────────────────────────────┐
│      Notebook Local (macOS)         │
│  ┌──────────────────────────────┐   │
│  │   terraform-dev-sandbox/     │   │
│  │   (este repositório)         │   │
│  │   - Makefile                 │   │
│  │   - infrastructure/          │   │
│  │   - config.env               │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │   /path/to/seu-modulo/       │   │
│  │   (configurável via config)  │   │
│  └──────────────────────────────┘   │
└─────────────────┬───────────────────┘
                  │ SSH + rsync
                  │ (porta 22)
                  ▼
┌─────────────────────────────────────┐
│         AWS Cloud                   │
│  ┌─────────────────────────────┐   │
│  │   EC2 Instance (Sandbox)    │   │
│  │  ┌─────────────────────┐    │   │
│  │  │ Terraform CLI       │    │   │
│  │  ├─────────────────────┤    │   │
│  │  │ tftest              │    │   │
│  │  ├─────────────────────┤    │   │
│  │  │ tfsec               │    │   │
│  │  ├─────────────────────┤    │   │
│  │  │ tflint              │    │   │
│  │  ├─────────────────────┤    │   │
│  │  │ Workspace (módulo)  │    │   │
│  │  └─────────────────────┘    │   │
│  │                             │   │
│  │  IAM Role attached          │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │   VPC + Security Groups     │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## 2. Componentes Detalhados

### 2.1 Infraestrutura AWS (Terraform)

#### 2.1.1 Estrutura de Arquivos
**Diretório**: `infrastructure/`

Arquivos organizados por recurso para fácil localização:
- `vpc.tf` - VPC e subnet pública
- `internet-gateway.tf` - Internet Gateway
- `security-group.tf` - Security Group para EC2
- `iam.tf` - IAM Role e Instance Profile
- `ec2.tf` - EC2 Instance
- `variables.tf` - Variáveis de entrada
- `outputs.tf` - Outputs (IP do EC2, etc)
- `user-data.sh` - Script de bootstrap do EC2
- `terraform.tfvars.example` - Exemplo de variáveis
- `versions.tf` - Versões de providers

#### 2.1.2 Security Group
Regras de entrada:
- SSH (porta 22) do IP do notebook

Regras de saída (restritivas):
- HTTPS (porta 443) - APIs dos providers (AWS, Azure, GCP, etc)
- HTTP (porta 80) - Downloads (Terraform Registry, packages)
- DNS (porta 53 UDP) - Resolução de nomes
- NTP (porta 123 UDP) - Sincronização de tempo

**Nota de Segurança**: Diferente de uma configuração totalmente aberta, este Security Group permite apenas os protocolos e portas necessários para o funcionamento do Terraform, seguindo o princípio de menor privilégio.

#### 2.1.3 IAM Role
Políticas necessárias:
- Permissões para providers Terraform que serão testados
- Permissões mínimas necessárias (princípio de menor privilégio)

#### 2.1.4 EC2 User Data
Script de inicialização para:
- Instalar Terraform
- Instalar tftest
- Instalar tfsec
- Instalar tflint
- Instalar Python e pip
- Configurar diretório de workspace
- Configurar SSH
- Instalar ferramentas auxiliares (git, make, etc)

### 2.2 Cliente de Sincronização (Notebook)

#### 2.2.1 Arquivo de Configuração
**Arquivo**: `config.env`

Configuração do caminho do módulo a ser desenvolvido:

```bash
# Caminho para o módulo Terraform que você está desenvolvendo
MODULE_PATH=/path/to/seu-modulo-terraform

# Configurações AWS
AWS_REGION=us-east-1

# Configurações SSH
SSH_KEY_PATH=~/.ssh/terraform-dev.pem
```

#### 2.2.2 Ferramenta: fswatch + rsync
**Escolha técnica**: Usar `fswatch` (macOS) para detectar mudanças + `rsync` para sincronização

**Importante**: 
- O repositório do módulo Terraform fica separado deste repositório
- Configure o caminho no `config.env`
- A sincronização aponta do módulo configurado para o EC2
- A pasta `.terraform/` só existe no EC2, nunca localmente
- O `.terraform.lock.hcl` também só existe no EC2
- Toda a lógica está integrada no Makefile (não precisa de scripts separados)

#### 2.2.3 Makefile Completo
**Arquivo**: `Makefile`

Todos os comandos de desenvolvimento centralizados:

```makefile
# Carregar configurações do arquivo config.env
include config.env

# Configuração
EC2_IP := $(shell cd infrastructure && terraform output -raw ec2_ip 2>/dev/null || echo "")
SSH_KEY := $(SSH_KEY_PATH)
REMOTE_USER := ec2-user
REMOTE_DIR := ~/workspace

# Comandos de sincronização
.PHONY: sync
sync:
	@echo "Sincronizando código com EC2..."
	@if [ -z "$(EC2_IP)" ]; then \
		echo "Erro: EC2 não provisionado. Execute 'make provision' primeiro"; \
		exit 1; \
	fi
	@if [ ! -d "$(MODULE_PATH)" ]; then \
		echo "Erro: Módulo não encontrado em $(MODULE_PATH)"; \
		echo "Configure MODULE_PATH no arquivo config.env"; \
		exit 1; \
	fi
	rsync -avz --exclude='.terraform/' \
	           --exclude='.git/' \
	           --exclude='*.tfstate*' \
	           --exclude='.terraform.lock.hcl' \
	           -e "ssh -i $(SSH_KEY)" \
	           $(MODULE_PATH)/ $(REMOTE_USER)@$(EC2_IP):$(REMOTE_DIR)/
	@echo "✓ Sincronização concluída"

.PHONY: watch
watch:
	@echo "Iniciando sincronização automática..."
	@if [ -z "$(EC2_IP)" ]; then \
		echo "Erro: EC2 não provisionado. Execute 'make provision' primeiro"; \
		exit 1; \
	fi
	@if [ ! -d "$(MODULE_PATH)" ]; then \
		echo "Erro: Módulo não encontrado em $(MODULE_PATH)"; \
		exit 1; \
	fi
	@echo "Monitorando mudanças em $(MODULE_PATH) e sincronizando com EC2 ($(EC2_IP))..."
	@cd $(MODULE_PATH) && fswatch -o . | while read; do \
		echo "Mudança detectada, sincronizando..."; \
		rsync -avz --exclude='.terraform/' \
		           --exclude='.git/' \
		           --exclude='*.tfstate*' \
		           --exclude='.terraform.lock.hcl' \
		           -e "ssh -i $(SSH_KEY)" \
		           . $(REMOTE_USER)@$(EC2_IP):$(REMOTE_DIR)/; \
		echo "✓ Sincronização concluída"; \
	done

# Comandos remotos
.PHONY: remote-shell
remote-shell:
	@if [ -z "$(EC2_IP)" ]; then \
		echo "Erro: EC2 não provisionado"; \
		exit 1; \
	fi
	ssh -i $(SSH_KEY) $(REMOTE_USER)@$(EC2_IP)

.PHONY: remote-exec
remote-exec:
	@if [ -z "$(EC2_IP)" ]; then \
		echo "Erro: EC2 não provisionado"; \
		exit 1; \
	fi
	ssh -i $(SSH_KEY) $(REMOTE_USER)@$(EC2_IP) "cd $(REMOTE_DIR) && $(CMD)"

# Comandos Terraform remotos
.PHONY: remote-init
remote-init:
	@echo "Executando terraform init no EC2..."
	@$(MAKE) remote-exec CMD="terraform init"

.PHONY: remote-plan
remote-plan:
	@echo "Executando terraform plan no EC2..."
	@$(MAKE) remote-exec CMD="terraform plan"

.PHONY: remote-apply
remote-apply:
	@echo "Executando terraform apply no EC2..."
	@$(MAKE) remote-exec CMD="terraform apply"

.PHONY: remote-validate
remote-validate:
	@echo "Validando código Terraform no EC2..."
	@$(MAKE) remote-exec CMD="terraform validate"

.PHONY: remote-fmt
remote-fmt:
	@echo "Formatando código Terraform no EC2..."
	@$(MAKE) remote-exec CMD="terraform fmt -recursive"

# Comandos de teste
.PHONY: remote-test
remote-test: sync remote-init
	@echo "Executando testes com tftest no EC2..."
	@$(MAKE) remote-exec CMD="tftest"

.PHONY: remote-tfsec
remote-tfsec: sync
	@echo "Executando tfsec no EC2..."
	@$(MAKE) remote-exec CMD="tfsec ."

.PHONY: remote-lint
remote-lint: sync
	@echo "Executando tflint no EC2..."
	@$(MAKE) remote-exec CMD="tflint --recursive"

# Pipeline completo de validação
.PHONY: remote-check
remote-check: sync remote-fmt remote-validate remote-lint remote-tfsec remote-test
	@echo "✓ Todas as verificações passaram!"

# Comandos de setup
.PHONY: setup
setup:
	@echo "Configurando ambiente local..."
	@echo "Verificando fswatch..."
	@which fswatch > /dev/null || (echo "Instalando fswatch..." && brew install fswatch)
	@echo "Verificando rsync..."
	@which rsync > /dev/null || (echo "rsync não encontrado!" && exit 1)
	@if [ ! -f "config.env" ]; then \
		echo "Criando config.env..."; \
		cp config.env.example config.env; \
		echo "⚠️  Configure o MODULE_PATH no arquivo config.env"; \
	fi
	@echo "✓ Ambiente configurado"

.PHONY: provision
provision:
	@echo "Provisionando infraestrutura EC2..."
	@cd infrastructure && terraform init && terraform apply
	@echo "✓ Infraestrutura provisionada"
	@echo "IP do EC2: $(shell cd infrastructure && terraform output -raw ec2_ip)"

.PHONY: stop
stop:
	@echo "Parando instância EC2..."
	@cd infrastructure && terraform apply -auto-approve -var="instance_state=stopped"
	@echo "✓ Instância EC2 parada"

.PHONY: start
start:
	@echo "Iniciando instância EC2..."
	@cd infrastructure && terraform apply -auto-approve -var="instance_state=running"
	@echo "✓ Instância EC2 iniciada"
	@echo "IP do EC2: $(shell cd infrastructure && terraform output -raw ec2_ip)"

.PHONY: destroy
destroy:
	@echo "⚠️  ATENÇÃO: Isso vai destruir TODA a infraestrutura!"
	@echo "Pressione Ctrl+C para cancelar ou Enter para continuar..."
	@read confirm
	@echo "Destruindo infraestrutura EC2..."
	@cd infrastructure && terraform destroy
	@echo "✓ Infraestrutura destruída"

# Comandos de limpeza
.PHONY: clean-remote
clean-remote:
	@echo "Limpando arquivos temporários no EC2..."
	@$(MAKE) remote-exec CMD="rm -rf .terraform/ *.tfstate* .terraform.lock.hcl"

# Status
.PHONY: status
status:
	@echo "Status do ambiente:"
	@echo "  Módulo: $(MODULE_PATH)"
	@if [ -z "$(EC2_IP)" ]; then \
		echo "  EC2: Não provisionado"; \
	else \
		echo "  EC2: Provisionado ($(EC2_IP))"; \
		ssh -i $(SSH_KEY) -o ConnectTimeout=5 $(REMOTE_USER)@$(EC2_IP) "echo '  Conexão: OK'" 2>/dev/null || echo "  Conexão: FALHOU"; \
	fi

# Help
.PHONY: help
help:
	@echo "Terraform Dev Sandbox - Comandos disponíveis:"
	@echo ""
	@echo "Setup:"
	@echo "  make setup          - Configura ambiente local (instala fswatch)"
	@echo "  make provision      - Provisiona infraestrutura EC2"
	@echo "  make start          - Inicia instância EC2 (se parada)"
	@echo "  make stop           - Para instância EC2"
	@echo "  make destroy        - Destrói TODA a infraestrutura"
	@echo ""
	@echo "Sincronização:"
	@echo "  make sync           - Sincroniza código uma vez"
	@echo "  make watch          - Sincronização automática contínua"
	@echo ""
	@echo "Execução Remota:"
	@echo "  make remote-shell   - Abre shell SSH no EC2"
	@echo "  make remote-init    - Executa terraform init"
	@echo "  make remote-plan    - Executa terraform plan"
	@echo "  make remote-apply   - Executa terraform apply"
	@echo "  make remote-validate- Valida sintaxe Terraform"
	@echo "  make remote-fmt     - Formata código Terraform"
	@echo ""
	@echo "Testes e Validação:"
	@echo "  make remote-test    - Executa tftest"
	@echo "  make remote-tfsec   - Executa tfsec (security)"
	@echo "  make remote-lint    - Executa tflint"
	@echo "  make remote-check   - Executa todas as verificações"
	@echo ""
	@echo "Utilitários:"
	@echo "  make status         - Mostra status do ambiente"
	@echo "  make clean-remote   - Limpa arquivos temporários no EC2"
```

### 2.3 Servidor EC2 (Sandbox)

#### 2.3.1 Sistema Operacional
Amazon Linux 2023 ou Ubuntu 22.04 LTS

#### 2.3.2 Estrutura de Diretórios
```
/home/ec2-user/
├── workspace/          # Código sincronizado do repositório
│   ├── .terraform/     # Apenas no EC2, nunca local
│   ├── .terraform.lock.hcl  # Apenas no EC2
│   ├── modules/        # Módulos Terraform
│   ├── tests/          # Testes
│   └── examples/       # Exemplos de uso
├── .terraform.d/       # Configurações Terraform
└── logs/               # Logs de execução
```

#### 2.3.3 Ferramentas Instaladas
- Terraform (última versão estável)
- tftest (framework de testes Terraform)
- tfsec (security scanning)
- tflint (linting)
- Python 3.11+
- terraform-docs
- git
- make

## 3. Fluxo de Trabalho

### 3.1 Setup Inicial
1. No diretório do seu repositório Terraform existente, adicionar os arquivos deste projeto
2. Executar `make setup` para instalar dependências locais (fswatch)
3. Executar `make provision` para provisionar EC2
4. Configurar SSH key localmente (`~/.ssh/terraform-dev.pem`)
5. Testar conexão: `make status`
6. Fazer primeira sincronização: `make sync`

### 3.2 Desenvolvimento Diário

**Opção 1: Sincronização Manual**
1. Desenvolver código no notebook
2. Executar `make sync` quando quiser testar
3. Executar `make remote-check` para validar
4. Ver resultados no terminal local

**Opção 2: Sincronização Automática**
1. Em um terminal, executar `make watch`
2. Em outro terminal, desenvolver normalmente
3. Cada salvamento sincroniza automaticamente
4. Executar `make remote-check` quando necessário

### 3.3 Execução de Testes

#### Pipeline Completo
```bash
make remote-check
```
Executa: fmt → validate → lint → tfsec → test

#### Testes Individuais
```bash
make remote-test      # tftest
make remote-tfsec     # security scan
make remote-lint      # linting
make remote-validate  # validação sintaxe
```

#### Terraform Operations
```bash
make remote-init
make remote-plan
make remote-apply
```

## 4. Propriedades de Corretude

### 4.1 Sincronização
**Propriedade 1.1**: Para qualquer arquivo modificado no notebook, o arquivo correspondente no EC2 deve ter o mesmo conteúdo após a sincronização
- **Validação**: Comparar checksums MD5 antes e depois

**Propriedade 1.2**: Arquivos excluídos (`.terraform/`, `.git/`, `infrastructure/`) não devem ser sincronizados
- **Validação**: Verificar que esses diretórios não existem no workspace do EC2 após sync

**Propriedade 1.3**: A pasta `.terraform/` nunca deve existir localmente
- **Validação**: `test ! -d .terraform/` deve retornar sucesso

### 4.2 Conectividade
**Propriedade 2.1**: O EC2 deve ser acessível via SSH do notebook
- **Validação**: `ssh -i key.pem ec2-user@<IP> echo "ok"` retorna "ok"

**Propriedade 2.2**: O EC2 deve ter acesso às APIs dos providers Terraform
- **Validação**: Executar `terraform init` com provider AWS deve suceder

### 4.3 Ambiente de Execução
**Propriedade 3.1**: Terraform deve estar instalado e funcional no EC2
- **Validação**: `terraform version` retorna versão válida

**Propriedade 3.2**: tftest deve estar instalado no EC2
- **Validação**: `tftest --version` retorna versão válida

**Propriedade 3.3**: tfsec deve estar instalado no EC2
- **Validação**: `tfsec --version` retorna versão válida

**Propriedade 3.4**: Credenciais AWS devem estar configuradas via IAM Role
- **Validação**: `aws sts get-caller-identity` retorna identidade válida

## 5. Decisões Técnicas

### 5.1 Por que rsync + fswatch?
- **Prós**: Simples, confiável, incremental, disponível nativamente
- **Contras**: Requer SSH, não é real-time (delay de ~1-2s)
- **Alternativas consideradas**: 
  - VS Code Remote SSH: Mais integrado, mas pode ter problemas com extensões
  - Mutagen: Mais robusto, mas adiciona dependência extra

**Decisão**: Começar com rsync+fswatch pela simplicidade

### 5.2 Por que tftest em vez de Terratest?
- **Razão**: tftest é mais leve e não requer Go
- Mais rápido para testes simples
- Menos dependências
- **Nota**: Pode migrar para Terratest se precisar de testes mais complexos

### 5.3 Por que EC2 e não Lambda/Fargate?
- **Razão**: Terraform precisa de ambiente stateful e de longa duração
- EC2 permite manter state local e cache de providers
- Mais fácil para debugging interativo
- `.terraform/` pode ser grande e precisa persistir

### 5.4 Gerenciamento de State
- **Opção 1**: State local no EC2 (simples, mas não compartilhável)
- **Opção 2**: S3 backend (mais robusto, compartilhável)

**Decisão**: Começar com state local, migrar para S3 se necessário

### 5.5 Separação de Infraestrutura
- O código Terraform da infraestrutura EC2 fica em `infrastructure/`
- O repositório de módulos Terraform existente fica na raiz
- `infrastructure/` é excluído da sincronização

### 5.6 Scripts vs Makefile
- **Decisão**: Integrar tudo no Makefile
- **Razão**: Menos arquivos, mais simples, tudo em um lugar
- Apenas o script `setup.sh` permanece para configuração inicial complexa

## 6. Segurança

### 6.1 Controle de Acesso
- Security Group limita SSH apenas ao IP do notebook
- IAM Role com princípio de menor privilégio
- SSH key pair única para este ambiente

### 6.2 Security Group Restritivo

O Security Group foi configurado seguindo o **princípio de menor privilégio**:

**Ingress (Entrada)**:
- ✅ SSH (porta 22) apenas do seu IP específico
- ❌ Todas as outras portas bloqueadas

**Egress (Saída) - Apenas o necessário**:
- ✅ HTTPS (443) - APIs dos providers (AWS, Azure, GCP, etc)
- ✅ HTTP (80) - Downloads (Terraform Registry, packages)
- ✅ DNS (53 UDP) - Resolução de nomes
- ✅ NTP (123 UDP) - Sincronização de tempo
- ❌ Todos os outros protocolos bloqueados

**Protocolos bloqueados** (não necessários para Terraform):
- SMTP (25) - Previne envio de spam
- SMB (445, 139) - Previne ataques de rede Windows
- RDP (3389) - Não necessário em Linux
- FTP (20, 21) - Não usado
- Telnet (23) - Inseguro e não usado

Esta configuração é **significativamente mais segura** que a alternativa comum de liberar todo o tráfego de saída (`0.0.0.0/0` em todas as portas).

### 6.3 Dados Sensíveis
- Nunca sincronizar arquivos `.tfvars` com secrets
- Manter secrets simples, sem uso de AWS Secrets Manager ou Parameter Store
- Adicionar `.tfvars` ao `.gitignore` e exclude do rsync
- Usar variáveis de ambiente quando necessário

### 6.3 Auditoria
- Logs de SSH no EC2 para auditoria básica
- Não usa CloudTrail (mantém simples)

### 6.4 tfsec
- Escaneia código Terraform para vulnerabilidades de segurança
- Verifica configurações inseguras
- Integrado no pipeline de validação

## 7. Custos Estimados

- EC2 t3.medium (2 vCPU, 4GB RAM): ~$30/mês (on-demand)
- Transferência de dados: ~$1-5/mês
- **Total estimado**: ~$35/mês

**Otimização**: 
- Usar instância spot (economia de ~70%)
- Parar quando não estiver em uso
- Script de auto-stop após inatividade

## 8. Melhorias Futuras

1. **Auto-stop**: Parar EC2 automaticamente após inatividade
2. **Multi-developer**: Suportar múltiplos desenvolvedores
3. **CI/CD**: Integrar com GitHub Actions
4. **Monitoring**: Dashboard com métricas de uso
5. **VS Code Integration**: Extensão customizada para controle
6. **Cache de Providers**: Compartilhar cache de providers entre execuções

## 9. Framework de Testes

### 9.1 tftest
**Framework principal**: tftest

**Características**:
- Testes declarativos em HCL
- Validação de outputs
- Testes de módulos
- Assertions customizadas

**Exemplo de teste**:
```hcl
# tests/module_test.tftest.hcl
run "test_vpc_creation" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR incorreto"
  }
}
```

### 9.2 tfsec
**Security scanning**: tfsec

**Verificações**:
- Security groups abertos
- Encryption não habilitado
- IAM policies muito permissivas
- Recursos públicos não intencionais

### 9.3 tflint
**Linting**: tflint

**Verificações**:
- Sintaxe e estilo
- Variáveis não utilizadas
- Recursos deprecated
- Best practices

## 10. Entregáveis

1. **Código Terraform de Infraestrutura** (`infrastructure/`)
   - `vpc.tf` - VPC e subnet
   - `internet-gateway.tf` - Internet Gateway
   - `security-group.tf` - Security Group
   - `iam.tf` - IAM Role e Instance Profile
   - `ec2.tf` - EC2 Instance
   - `variables.tf` - Variáveis de entrada
   - `outputs.tf` - Outputs (IP do EC2, etc)
   - `user-data.sh` - Script de bootstrap do EC2
   - `terraform.tfvars.example` - Exemplo de variáveis
   - `versions.tf` - Versões de providers

2. **Script de Setup** (`scripts/`)
   - `setup.sh` - Setup inicial (configura SSH, verifica dependências)

3. **Makefile** (raiz do repositório)
   - Todos os comandos centralizados incluindo watch
   - Help integrado

4. **README.md** (raiz do repositório)
   - Documentação minimalista e enxuta
   - Quick start em poucos minutos
   - Comandos principais apenas
   - Link para documentação detalhada

5. **Documentação Detalhada** (`docs/`)
   - `SETUP.md` - Guia de configuração inicial completo
   - `USAGE.md` - Guia de uso diário detalhado
   - `TROUBLESHOOTING.md` - Resolução de problemas
   - `ARCHITECTURE.md` - Detalhes da arquitetura
   - `CONTRIBUTING.md` - Guia de contribuição

6. **Configurações** (raiz do repositório)
   - `config.env.example` - Exemplo de configuração
   - `.gitignore` - Ignora `.terraform/`, states, config.env, etc
   - `.ai-rules` - Regras e contexto para agentes de IA

7. **Memory Bank** (`.ai/memory/`)
   - `codebase.md` - Contexto estruturado do repositório para agentes de IA
   - Economiza tokens e tempo em interações com assistentes de código
   - Mantém contexto atualizado do projeto
   - Agnóstico a ferramentas específicas

### 10.1 Conteúdo do README.md (Minimalista)

```markdown
# Terraform Dev Sandbox

Ambiente de desenvolvimento Terraform com sincronização automática para EC2.

## Quick Start

```bash
# 1. Clone e configure
git clone <repo> terraform-dev-sandbox
cd terraform-dev-sandbox
make setup

# 2. Configure o módulo
vim config.env  # Defina MODULE_PATH

# 3. Provisione EC2
make provision

# 4. Sincronize e desenvolva
make watch      # Em um terminal
# Desenvolva no seu módulo em outro terminal

# 5. Teste
make remote-check
```

## Comandos Principais

```bash
make help           # Ver todos os comandos
make provision      # Criar infraestrutura
make watch          # Sincronização automática
make remote-check   # Executar todos os testes
make stop           # Parar EC2
make destroy        # Destruir tudo
```

## Documentação

Veja [docs/](docs/) para documentação completa:
- [Setup](docs/SETUP.md) - Configuração detalhada
- [Usage](docs/USAGE.md) - Guia de uso
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Resolução de problemas
- [Architecture](docs/ARCHITECTURE.md) - Detalhes técnicos
- [Contributing](docs/CONTRIBUTING.md) - Como contribuir

## Licença

MIT
```

### 10.2 Estrutura da Documentação em docs/

#### docs/SETUP.md
- Pré-requisitos detalhados
- Instalação passo a passo
- Configuração de credenciais AWS
- Configuração de SSH keys
- Troubleshooting de instalação

#### docs/USAGE.md
- Fluxo de trabalho diário
- Comandos detalhados com exemplos
- Sincronização manual vs automática
- Execução de testes
- Debugging remoto
- Boas práticas

#### docs/TROUBLESHOOTING.md
- Problemas comuns e soluções
- Erros de conexão SSH
- Problemas de sincronização
- Erros do Terraform
- Performance issues
- Como obter logs

#### docs/ARCHITECTURE.md
- Diagrama de arquitetura detalhado
- Componentes e suas responsabilidades
- Decisões técnicas
- Fluxo de dados
- Segurança
- Custos

#### docs/CONTRIBUTING.md
- Como contribuir
- Padrões de código
- Como reportar bugs
- Como sugerir features
- Processo de pull request
- Código de conduta

### 10.3 Conteúdo do .ai-rules

Arquivo na raiz do projeto com regras e contexto para agentes de IA:

```markdown
# AI Rules - Terraform Dev Sandbox

## Contexto do Projeto
Este é um repositório genérico e reutilizável para criar ambientes de desenvolvimento Terraform com sincronização automática para EC2. O objetivo é permitir desenvolvimento local de módulos Terraform quando as APIs dos providers estão bloqueadas, executando testes remotamente no EC2.

## Arquitetura
- Repositório separado do módulo sendo desenvolvido
- Configuração via `config.env` aponta para módulo externo
- Sincronização automática (rsync + fswatch) do módulo para EC2
- `.terraform/` existe apenas no EC2, nunca localmente

## Regras de Código

### Terraform
- Um arquivo `.tf` por recurso (não usar `main.tf` monolítico)
- Nomenclatura: `vpc.tf`, `ec2.tf`, `iam.tf`, `security-group.tf`, etc
- Sempre incluir `versions.tf` com versões de providers
- Usar `terraform.tfvars.example` para exemplos de variáveis

### Makefile
- Todos os targets devem usar `.PHONY`
- Mensagens claras de erro e sucesso
- Validar pré-condições (EC2 provisionado, config.env existe, etc)
- Incluir help detalhado

### Bash Scripts
- Sempre validar erros (`set -e` ou verificações explícitas)
- Mensagens claras de progresso
- Validar pré-requisitos antes de executar

### Documentação
- README.md: Minimalista, quick start em 5 passos
- docs/: Documentação detalhada e completa
- Comentários em código apenas quando necessário

## Padrões de Nomenclatura
- Arquivos: kebab-case (`security-group.tf`, `user-data.sh`)
- Variáveis Terraform: snake_case (`instance_type`, `vpc_cidr`)
- Targets Makefile: kebab-case (`remote-check`, `remote-shell`)
- Variáveis ambiente: UPPER_SNAKE_CASE (`MODULE_PATH`, `EC2_IP`)

## Estrutura de Commits
- feat: Nova funcionalidade
- fix: Correção de bug
- docs: Mudanças em documentação
- refactor: Refatoração de código
- test: Adição ou modificação de testes
- chore: Tarefas de manutenção

## Não Fazer
- Não usar AWS Secrets Manager ou Parameter Store (manter simples)
- Não usar CloudTrail (manter simples)
- Não criar `.terraform/` localmente
- Não commitar `config.env` (apenas `config.env.example`)
- Não usar `main.tf` monolítico

## Prioridades
1. Simplicidade sobre complexidade
2. Configurabilidade (trocar de módulo facilmente)
3. Documentação clara e concisa
4. Comandos intuitivos via Makefile

## Memory Bank
Consulte `.ai/memory/codebase.md` para contexto completo do repositório.
```

### 10.4 Conteúdo do Memory Bank (.ai/memory/codebase.md)

Estrutura agnóstica para qualquer assistente de código IA:

```markdown
# Terraform Dev Sandbox

## Overview
Repositório genérico e reutilizável para criar ambientes de desenvolvimento Terraform com sincronização automática para EC2. Resolve o problema de desenvolver módulos Terraform localmente quando as APIs dos providers estão bloqueadas, permitindo execução de testes remotamente no EC2 com acesso completo às APIs.

## Purpose
Permitir que desenvolvedores:
- Desenvolvam módulos Terraform localmente no notebook
- Sincronizem código automaticamente para EC2 na AWS
- Executem testes (tftest, tfsec, tflint) remotamente
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
   - Instância EC2 com Terraform, tftest, tfsec, tflint
   - Workspace com código sincronizado
   - `.terraform/` (existe apenas aqui, nunca local)
   - IAM Role para acesso aos providers

3. **Infrastructure (Terraform)**
   - VPC e subnet pública
   - Security Group (SSH do notebook)
   - IAM Role e Instance Profile
   - EC2 Instance com user data
   - Elastic IP (opcional)

### Data Flow
```
Notebook (módulo) → fswatch detecta mudança → rsync sincroniza → EC2 (workspace)
Notebook ← SSH ← Resultados de testes ← EC2
```

## Project Structure

```
terraform-dev-sandbox/
├── infrastructure/           # Terraform para provisionar EC2
│   ├── vpc.tf               # VPC e subnet
│   ├── internet-gateway.tf  # Internet Gateway
│   ├── security-group.tf    # Security Group
│   ├── iam.tf               # IAM Role e Instance Profile
│   ├── ec2.tf               # EC2 Instance
│   ├── variables.tf         # Variáveis de entrada
│   ├── outputs.tf           # Outputs (IP do EC2)
│   ├── user-data.sh         # Bootstrap do EC2
│   ├── versions.tf          # Versões de providers
│   └── terraform.tfvars.example
├── scripts/
│   └── setup.sh             # Setup inicial
├── docs/
│   ├── SETUP.md             # Configuração detalhada
│   ├── USAGE.md             # Guia de uso
│   ├── TROUBLESHOOTING.md   # Resolução de problemas
│   ├── ARCHITECTURE.md      # Detalhes técnicos
│   └── CONTRIBUTING.md      # Guia de contribuição
├── .ai/
│   └── memory/
│       └── codebase.md      # Este arquivo
├── Makefile                 # Todos os comandos
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
- `vpc.tf` - Rede
- `security-group.tf` - Firewall
- `iam.tf` - Permissões
- `ec2.tf` - Instância

## Workflows

### Initial Setup
1. Clone: `git clone <repo> terraform-dev-sandbox`
2. Setup: `make setup` (instala fswatch, cria config.env)
3. Configure: Editar `config.env` com MODULE_PATH
4. Provision: `make provision` (cria EC2)
5. Sync: `make sync` (primeira sincronização)
6. Validate: `make remote-check`

### Daily Development
**Option 1: Manual Sync**
1. Desenvolver código no módulo
2. `make sync` quando quiser testar
3. `make remote-check` para validar

**Option 2: Auto Sync**
1. Terminal 1: `make watch` (sincronização contínua)
2. Terminal 2: Desenvolver normalmente
3. `make remote-check` quando necessário

### Switching Modules
1. Editar `config.env` e mudar MODULE_PATH
2. `make sync` para sincronizar novo módulo
3. Continuar desenvolvimento

Não precisa recriar infraestrutura!

## Technologies

### Core
- **Terraform**: Infraestrutura como código
- **AWS EC2**: Ambiente de execução remoto
- **rsync**: Sincronização incremental de arquivos
- **fswatch**: Monitoramento de mudanças (macOS)

### Testing Tools
- **tftest**: Framework de testes Terraform (HCL)
- **tfsec**: Security scanning
- **tflint**: Linting e best practices

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

## Commands Reference

### Setup Commands
```bash
make setup      # Instala fswatch, cria config.env
make provision  # Cria infraestrutura EC2
make start      # Inicia EC2 (se parado)
make stop       # Para EC2
make destroy    # Destrói toda infraestrutura
```

### Sync Commands
```bash
make sync       # Sincroniza código uma vez
make watch      # Sincronização automática contínua
```

### Remote Commands
```bash
make remote-shell    # Abre shell SSH no EC2
make remote-init     # terraform init
make remote-plan     # terraform plan
make remote-apply    # terraform apply
make remote-validate # terraform validate
make remote-fmt      # terraform fmt
```

### Test Commands
```bash
make remote-test     # Executa tftest
make remote-tfsec    # Executa tfsec (security)
make remote-lint     # Executa tflint
make remote-check    # Pipeline completo (fmt→validate→lint→tfsec→test)
```

### Utility Commands
```bash
make status         # Mostra status do ambiente
make clean-remote   # Limpa arquivos temporários no EC2
make help           # Mostra todos os comandos
```

## Configuration

### config.env
```bash
# Caminho para o módulo Terraform que você está desenvolvendo
MODULE_PATH=/path/to/seu-modulo-terraform

# Configurações AWS
AWS_REGION=us-east-1

# Configurações SSH
SSH_KEY_PATH=~/.ssh/terraform-dev.pem
```

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
cat config.env

# Verificar se módulo existe
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

## Cost Estimation
- EC2 t3.medium: ~$30/mês (on-demand)
- Elastic IP: $3.60/mês (se não associado)
- Data transfer: ~$1-5/mês
- **Total**: ~$35-40/mês

**Optimization**:
- Use spot instances (~70% savings)
- Stop EC2 when not in use (`make stop`)
- Destroy when project ends (`make destroy`)

## Contributing
See [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md) for contribution guidelines.

## License
MIT
```

## 11. Integração com Repositório Existente

### 11.1 Estrutura Final
```
terraform-dev-sandbox/         # Este repositório (genérico e reutilizável)
├── infrastructure/            # Infraestrutura do sandbox
│   ├── vpc.tf
│   ├── internet-gateway.tf
│   ├── security-group.tf
│   ├── iam.tf
│   ├── ec2.tf
│   ├── eip.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── user-data.sh
│   ├── terraform.tfvars.example
│   └── versions.tf
├── scripts/                   # Scripts auxiliares
│   └── setup.sh
├── docs/                      # Documentação
│   ├── SETUP.md
│   ├── USAGE.md
│   ├── TROUBLESHOOTING.md
│   ├── ARCHITECTURE.md
│   └── CONTRIBUTING.md
├── .ai/                       # Contexto para agentes de IA
│   └── memory/
│       └── codebase.md        # Memory bank
├── Makefile                   # Todos comandos
├── config.env.example         # Exemplo de configuração
├── .gitignore
└── README.md

/path/to/seu-modulo/          # Seu módulo Terraform (separado)
├── main.tf
├── variables.tf
├── outputs.tf
├── tests/
└── examples/
```

### 11.2 Configuração do .gitignore
```
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.backup

# SSH keys
*.pem
*.key

# Configuração local
config.env

# Infraestrutura local
infrastructure/.terraform/
infrastructure/*.tfstate*
infrastructure/.terraform.lock.hcl
```

### 11.3 Primeiro Uso
1. Clonar este repositório: `git clone <repo> terraform-dev-sandbox`
2. Entrar no diretório: `cd terraform-dev-sandbox`
3. Executar `make setup` (cria config.env e instala fswatch)
4. Editar `config.env` e configurar `MODULE_PATH` para seu módulo
5. Executar `make provision` (cria EC2)
6. Executar `make sync` (primeira sincronização)
7. Executar `make remote-check` (valida tudo)
8. Começar desenvolvimento com `make watch` em um terminal

### 11.4 Trocar de Módulo
Para desenvolver outro módulo:
1. Editar `config.env` e mudar `MODULE_PATH`
2. Executar `make sync` para sincronizar novo módulo
3. Continuar desenvolvimento normalmente

Não precisa recriar a infraestrutura!

# Guia de Testes - Terraform Dev Sandbox

Este documento descreve como executar os testes de validação do projeto.

## Pré-requisitos

- Conta AWS configurada (`aws configure`)
- Credenciais AWS com permissões para criar VPC, EC2, Security Groups, IAM Roles
- Terraform instalado localmente (opcional, mas recomendado)
- fswatch instalado (`brew install fswatch`)
- Módulo Terraform de exemplo para testar

## 1. Testes de Código (Sem AWS)

### 1.1 Validação Terraform

```bash
cd infrastructure
terraform init
terraform validate
```

**Resultado esperado**: `Success! The configuration is valid.`

### 1.2 Formatação

```bash
terraform fmt -check -recursive infrastructure/
```

**Resultado esperado**: Sem output (código formatado corretamente)

### 1.3 Security Scan (tfsec)

```bash
tfsec infrastructure/
```

**Resultado esperado**: `No problems detected!`

## 2. Testes de Provisionamento (Requer AWS)

### 2.1 Setup Inicial

```bash
# 1. Executar setup
make setup

# Resultado esperado:
# ✓ fswatch encontrado
# ✓ rsync encontrado
# ✓ Arquivo config.env criado
```

### 2.2 Configurar Variáveis

```bash
# 1. Editar config.env
vim config.env

# Configurar:
# MODULE_PATH=/path/to/seu-modulo-terraform
# AWS_REGION=us-east-1
# AWS_PROFILE=default
# SSH_KEY_PATH=~/.ssh/terraform-dev.pem

# 2. Editar infrastructure/terraform.tfvars (opcional)
vim infrastructure/terraform.tfvars

# Configurar (se necessário):
# my_ip = "SEU_IP/32"  # Obtenha em: curl https://ifconfig.me
# instance_type = "t3.small"
```

### 2.3 Provisionar Infraestrutura

```bash
make provision
```

**Resultado esperado**:
```
Provisionando infraestrutura EC2...
...
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
✓ Infraestrutura provisionada
IP do EC2: 54.123.45.67
```

**Validações**:
- [ ] VPC criada
- [ ] Subnet pública criada
- [ ] Internet Gateway criado
- [ ] Security Group criado
- [ ] IAM Role criado
- [ ] EC2 Instance criada
- [ ] VPC Flow Logs criados
- [ ] CloudWatch Log Group criado

### 2.4 Verificar Status

```bash
make status
```

**Resultado esperado**:
```
Status do ambiente:
  Módulo: /path/to/seu-modulo
  EC2: Provisionado (54.123.45.67)
  Conexão: OK
```

## 3. Testes de Conectividade SSH

### 3.1 Testar Conexão SSH

```bash
make remote-shell
```

**Resultado esperado**: Shell SSH aberto no EC2

**Validações no EC2**:
```bash
# Verificar ferramentas instaladas
terraform version    # Deve mostrar versão 1.7.0+
tfsec --version      # Deve mostrar versão instalada
tflint --version     # Deve mostrar versão instalada
terraform-docs --version  # Deve mostrar versão instalada

# Verificar AWS CLI
aws sts get-caller-identity  # Deve mostrar identidade IAM

# Verificar diretórios
ls -la ~/workspace/  # Deve existir
ls -la ~/logs/       # Deve existir

# Sair
exit
```

## 4. Testes de Sincronização

### 4.1 Criar Módulo de Teste

```bash
# Criar módulo de exemplo
mkdir -p /tmp/test-terraform-module
cd /tmp/test-terraform-module

cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.5.0"
}

resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo 'Hello from Terraform!'"
  }
}
EOF

# Configurar MODULE_PATH
cd ~/terraform-dev-sandbox
vim config.env
# MODULE_PATH=/tmp/test-terraform-module
```

### 4.2 Testar Sincronização Manual

```bash
make sync
```

**Resultado esperado**:
```
Sincronizando código com EC2...
sending incremental file list
main.tf
✓ Sincronização concluída
```

**Validação**:
```bash
make remote-exec CMD="ls -la ~/workspace/"
# Deve mostrar main.tf
```

### 4.3 Testar Sincronização Automática

```bash
# Terminal 1: Iniciar watch
make watch

# Terminal 2: Fazer mudanças
cd /tmp/test-terraform-module
echo '# Comentário' >> main.tf

# Terminal 1: Deve mostrar
# Mudança detectada, sincronizando...
# ✓ Sincronização concluída
```

### 4.4 Verificar Exclusões

```bash
# Criar .terraform/ localmente (não deve sincronizar)
cd /tmp/test-terraform-module
mkdir -p .terraform/providers
echo "test" > .terraform/test.txt

# Sincronizar
make sync

# Verificar que .terraform/ NÃO foi sincronizado
make remote-exec CMD="ls -la ~/workspace/.terraform/ 2>&1"
# Deve mostrar: No such file or directory
```

## 5. Testes do Seu Módulo Terraform

### 5.1 Estrutura de Testes Recomendada

Organize seus testes no diretório `tests/` do seu módulo:

```
seu-modulo/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── unit-test-1.tftest.hcl
    ├── unit-test-2.tftest.hcl
    └── integration-test.tftest.hcl
```

### 5.2 Exemplo de Teste Unitário

```hcl
# tests/unit-vpc.tftest.hcl

# Mock do provider AWS
mock_provider "aws" {
  override_during = apply
}

# Teste 1: Validar configuração da VPC
run "validate_vpc_cidr" {
  command = plan

  variables {
    vpc_name = "test-vpc"
    vpc_cidr = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == var.vpc_cidr
    error_message = "VPC CIDR deve corresponder à variável"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames deve estar habilitado"
  }
}

# Teste 2: Validar tags
run "validate_vpc_tags" {
  command = plan

  variables {
    vpc_name = "test-vpc"
    vpc_cidr = "10.0.0.0/16"
    tags = {
      Environment = "test"
      Project     = "my-project"
    }
  }

  assert {
    condition     = aws_vpc.main.tags["Environment"] == "test"
    error_message = "Tag Environment deve ser 'test'"
  }
}
```

### 5.3 Executar Testes do Seu Módulo

**Passo 1: Configurar MODULE_PATH**
```bash
# Opção 1: Interativo
make configure

# Opção 2: Manual
vim config.env
# MODULE_PATH=/path/to/seu-modulo
```

**Passo 2: Sincronizar**
```bash
make sync
```

**Passo 3: Executar Testes**
```bash
# Todos os testes
make remote-test

# Apenas validação
make remote-validate

# Apenas formatação
make remote-fmt

# Pipeline completo
make remote-check
```

**Resultado esperado**:
```
Executando testes com tftest no EC2...
tests/unit-vpc.tftest.hcl... in progress
  run "validate_vpc_cidr"... pass
  run "validate_vpc_tags"... pass
tests/unit-vpc.tftest.hcl... pass

Success! 2 passed, 0 failed.
```

### 5.4 Debugging de Testes Falhados

Se um teste falhar:

```bash
# 1. Ver logs detalhados
make remote-exec CMD="terraform test -verbose"

# 2. Executar teste específico
make remote-exec CMD="terraform test -filter=unit-vpc"

# 3. Ver plano do teste
make remote-exec CMD="terraform test -verbose 2>&1 | grep -A 20 'Error:'"

# 4. Acessar EC2 para debug interativo
make remote-shell
cd ~/workspace
terraform test -verbose
```

### 5.5 Boas Práticas para Testes

**1. Use Mocks para Testes Unitários**
```hcl
mock_provider "aws" {
  override_during = apply
}
```

**2. Nomeie Testes Descritivamente**
```hcl
run "should_create_vpc_with_correct_cidr" { ... }
run "should_enable_dns_hostnames_by_default" { ... }
run "should_apply_all_required_tags" { ... }
```

**3. Teste Casos de Sucesso e Falha**
```hcl
run "should_accept_valid_cidr" { ... }
run "should_reject_invalid_cidr" {
  command = plan
  expect_failures = [var.vpc_cidr]
}
```

**4. Organize Testes por Funcionalidade**
```
tests/
├── unit-networking.tftest.hcl
├── unit-security.tftest.hcl
├── unit-compute.tftest.hcl
└── integration-full-stack.tftest.hcl
```

**5. Use Variáveis para Reutilização**
```hcl
variables {
  common_tags = {
    Environment = "test"
    ManagedBy   = "terraform"
  }
}
```

### 5.1 Terraform Init

```bash
make remote-init
```

**Resultado esperado**: Terraform inicializado com sucesso

### 5.2 Terraform Validate

```bash
make remote-validate
```

**Resultado esperado**: `Success! The configuration is valid.`

### 5.3 Terraform Plan

```bash
make remote-plan
```

**Resultado esperado**: Plan executado (pode mostrar recursos a criar)

### 5.4 Terraform Format

```bash
make remote-fmt
```

**Resultado esperado**: Código formatado

## 6. Testes de Pipeline de Validação

### 6.1 Teste Individual - tfsec

```bash
make remote-tfsec
```

**Resultado esperado**: Security scan executado

### 6.2 Teste Individual - tflint

```bash
make remote-lint
```

**Resultado esperado**: Linting executado

### 6.3 Teste Individual - terraform test

```bash
make remote-test
```

**Resultado esperado**: Testes executados (se houver arquivos .tftest.hcl)

### 6.4 Pipeline Completo

```bash
make remote-check
```

**Resultado esperado**:
```
Sincronizando código com EC2...
✓ Sincronização concluída
Formatando código Terraform no EC2...
Validando código Terraform no EC2...
Executando tflint no EC2...
Executando tfsec no EC2...
Executando testes com terraform test no EC2...
✓ Todas as verificações passaram!
```

## 7. Testes Unitários da Infraestrutura (tftest)

Os testes unitários validam a infraestrutura do sandbox usando Terraform Test. Estes testes garantem que a infraestrutura está configurada corretamente antes de provisionar.

### 7.1 Estrutura de Testes

```
infrastructure/tests/
├── vpc.tftest.hcl
├── subnet.tftest.hcl
├── internet-gateway.tftest.hcl
├── security-group.tftest.hcl
├── iam.tftest.hcl
└── ec2.tftest.hcl
```

### 7.2 Executar Testes Localmente

**Pré-requisitos**: Credenciais AWS configuradas

```bash
# Executar todos os testes
make test

# Executar com output detalhado
make test-verbose
```

**Resultado esperado**:
```
Executando testes da infraestrutura...
vpc.tftest.hcl... pass
subnet.tftest.hcl... pass
internet-gateway.tftest.hcl... pass
security-group.tftest.hcl... pass
iam.tftest.hcl... pass
ec2.tftest.hcl... pass

Success! 15 passed, 0 failed.
```

### 7.3 Executar Testes no EC2

Se as APIs estão bloqueadas localmente, execute os testes no EC2:

```bash
# Sincronizar e executar testes remotamente
make remote-test
```

**Resultado esperado**:
```
Sincronizando código com EC2...
✓ Sincronização concluída
Executando testes com tftest no EC2...
vpc.tftest.hcl... pass
subnet.tftest.hcl... pass
internet-gateway.tftest.hcl... pass
security-group.tftest.hcl... pass
iam.tftest.hcl... pass
ec2.tftest.hcl... pass

Success! 15 passed, 0 failed.
```

### 7.4 Cobertura de Testes

**Recursos testados** (10/14 = 71%):
- ✅ VPC (CIDR, DNS, tags)
- ✅ Subnet (CIDR, public IP, availability zone)
- ✅ Internet Gateway (associação VPC)
- ✅ Route Table (rotas, associação subnet)
- ✅ Security Group (regras SSH, egress)
- ✅ IAM Role (assume role policy, managed policies)
- ✅ IAM Instance Profile (associação role)
- ✅ EC2 Instance (AMI, instance type, user-data, tags)
- ✅ Key Pair (chave SSH)
- ✅ Null Resource (provisioner)

**Recursos não testados** (4/14 = 29%):
- ⚠️ aws_route_table_association (auxiliar, testado indiretamente)
- ⚠️ data.aws_availability_zones (data source, não requer teste)
- ⚠️ data.aws_ami (data source, não requer teste)
- ⚠️ aws_iam_role_policy_attachment (auxiliar, testado indiretamente)

**Cobertura de recursos críticos**: 100% ✅

### 7.5 Estrutura de um Teste

Exemplo: `tests/vpc.tftest.hcl`

```hcl
# Teste da VPC
run "validate_vpc" {
  command = plan

  # Validar CIDR block
  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR deve ser 10.0.0.0/16"
  }

  # Validar DNS habilitado
  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames deve estar habilitado"
  }

  # Validar tags obrigatórias
  assert {
    condition     = aws_vpc.main.tags["Environment"] == "development"
    error_message = "Tag Environment deve ser 'development'"
  }
}
```

### 7.6 Convenções de Testes

1. **Um arquivo por recurso**: Cada arquivo testa um tipo de recurso
2. **Nomes descritivos**: `validate_<recurso>` para testes de validação
3. **Assertions claras**: Mensagens de erro explicativas
4. **Command = plan**: Testes não criam recursos reais (apenas validam plano)
5. **Tags obrigatórias**: Todos os recursos devem ter tags `Environment` e `ManagedBy`

### 7.7 Adicionar Novos Testes

Para adicionar um novo teste:

```bash
# 1. Criar arquivo de teste
cat > infrastructure/tests/novo-recurso.tftest.hcl << 'EOF'
run "validate_novo_recurso" {
  command = plan

  assert {
    condition     = <condição>
    error_message = "<mensagem>"
  }
}
EOF

# 2. Executar teste
make test

# 3. Verificar resultado
# Se falhar, ajustar código ou teste
```

### 7.8 Troubleshooting de Testes

#### Erro: "No configuration files"
```bash
# Verificar que está no diretório correto
cd infrastructure
terraform test
```

#### Erro: "Error: Invalid function argument"
```bash
# Verificar variáveis em terraform.tfvars
cat terraform.tfvars
# Adicionar variáveis faltantes
```

#### Erro: "Error: Insufficient IAM permissions"
```bash
# Verificar credenciais AWS
aws sts get-caller-identity

# Verificar permissões necessárias:
# - ec2:Describe*
# - iam:Get*
# - iam:List*
```

#### Teste falha: "Tag Environment deve ser 'development'"
```bash
# Adicionar tag ao recurso
# Em infrastructure/<recurso>.tf:
tags = {
  Environment = "development"
  ManagedBy   = "terraform"
}
```

### 7.9 Ciclo TDD para Infraestrutura

Ao modificar a infraestrutura, siga o ciclo TDD:

```bash
# 1. Executar testes regressivos (devem passar)
make test

# 2. Adicionar novo teste (deve falhar)
vim infrastructure/tests/novo-teste.tftest.hcl
make test  # Deve falhar

# 3. Implementar código mínimo
vim infrastructure/<recurso>.tf
make test  # Deve passar

# 4. Refatorar se necessário
vim infrastructure/<recurso>.tf
make test  # Deve continuar passando

# 5. Executar todos os testes regressivos
make test  # Todos devem passar
```

### 7.10 Integração com CI/CD

Os testes podem ser integrados em pipelines CI/CD:

```yaml
# Exemplo: GitHub Actions
name: Infrastructure Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - name: Run tests
        run: make test
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## 8. Testes de Gerenciamento de Infraestrutura

### 8.1 Parar EC2

```bash
make stop
```

**Resultado esperado**:
```
Parando instância EC2...
✓ Instância EC2 parada
```

**Validação**:
```bash
make status
# Deve mostrar: Conexão: FALHOU (esperado quando parado)
```

### 8.2 Iniciar EC2

```bash
make start
```

**Resultado esperado**:
```
Iniciando instância EC2...
✓ Instância EC2 iniciada
IP do EC2: 54.123.45.67
```

**Validação**:
```bash
make status
# Deve mostrar: Conexão: OK
```

### 8.3 Verificar IP Dinâmico

```bash
# Anotar IP atual
make status

# Parar e iniciar
make stop
sleep 30
make start

# Verificar novo IP
make status

# NOTA: IP pode ter mudado (comportamento esperado sem Elastic IP)
```

## 9. Testes de Troca de Módulo

### 9.1 Criar Segundo Módulo

```bash
mkdir -p /tmp/test-terraform-module-2
cd /tmp/test-terraform-module-2

cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.5.0"
}

output "message" {
  value = "Hello from module 2!"
}
EOF
```

### 9.2 Trocar Módulo

```bash
cd ~/terraform-dev-sandbox
vim config.env
# MODULE_PATH=/tmp/test-terraform-module-2

make sync
```

**Validação**:
```bash
make remote-exec CMD="cat ~/workspace/main.tf"
# Deve mostrar conteúdo do módulo 2
```

## 10. Testes de Limpeza

### 10.1 Limpar Arquivos Remotos

```bash
make clean-remote
```

**Resultado esperado**: Arquivos temporários removidos

### 10.2 Destruir Infraestrutura

```bash
make destroy
```

**Resultado esperado**:
```
⚠️  ATENÇÃO: Isso vai destruir TODA a infraestrutura!
Pressione Ctrl+C para cancelar ou Enter para continuar...
[Enter]
Destruindo infraestrutura EC2...
Destroy complete! Resources: 15 destroyed.
✓ Infraestrutura destruída
```

## 11. Troubleshooting de Testes

### 11.1 Erro: "Missing required provider"

**Problema**: Testes falham com erro de provider não encontrado

**Causa**: `terraform init` não foi executado na pasta `tests/`

**Solução**:
```bash
# O comando make remote-test já faz isso automaticamente
make remote-test

# Ou manualmente:
make remote-exec CMD="(cd tests && terraform init) && terraform test"
```

### 11.2 Erro: "Unexpected provider configuration"

**Problema**: Conflito entre mock_provider e provider real

**Causa**: Provider configurado no módulo conflita com mock nos testes

**Solução**: Remover configuração de provider do módulo ou ajustar testes
```hcl
# Opção 1: Usar mock apenas durante apply
mock_provider "aws" {
  override_during = apply
}

# Opção 2: Não usar mock se provider real for necessário
# (remover bloco mock_provider)
```

### 11.3 Erro: "No value for required variable"

**Problema**: Variáveis obrigatórias não fornecidas nos testes

**Solução**: Adicionar bloco `variables` no teste
```hcl
run "test_name" {
  command = plan

  variables {
    required_var_1 = "value1"
    required_var_2 = "value2"
  }
}
```

### 11.4 Testes Lentos

**Problema**: Testes demoram muito para executar

**Causas e Soluções**:

1. **Muitos providers para baixar**
   ```bash
   # Usar cache de providers (já configurado no EC2)
   # Primeira execução: ~30-60s
   # Execuções seguintes: ~5-10s
   ```

2. **Testes de integração criando recursos reais**
   ```hcl
   # Usar command = plan ao invés de apply
   run "test_name" {
     command = plan  # Não cria recursos
   }
   ```

3. **Muitos testes sequenciais**
   ```bash
   # Executar apenas testes específicos
   make remote-exec CMD="terraform test -filter=unit-*"
   ```

### 11.5 Erro: "Backend configuration ignored"

**Problema**: Warning sobre backend configuration na pasta tests/

**Causa**: Arquivo `backend_override.tf` no diretório raiz afeta tests/

**Solução**: Isso é apenas um warning, pode ser ignorado. O backend é configurado no módulo raiz, não nos testes.

### 11.6 Testes Passam Localmente mas Falham no EC2

**Causas Possíveis**:

1. **Versão diferente do Terraform**
   ```bash
   # Verificar versão no EC2
   make remote-exec CMD="terraform version"
   
   # tfenv instala automaticamente a versão correta
   # baseada em required_version
   ```

2. **Providers diferentes**
   ```bash
   # Limpar cache e reinstalar
   make clean-remote
   make remote-test
   ```

3. **Variáveis de ambiente diferentes**
   ```bash
   # Verificar variáveis no EC2
   make remote-exec CMD="env | grep TF_"
   ```

### 11.7 Erro: "Error acquiring the state lock"

**Problema**: Lock do Terraform travado

**Solução**:
```bash
# Remover lock file
make remote-exec CMD="rm -f .terraform.tfstate.lock.info"

# Ou usar -lock=false
make remote-exec CMD="terraform test -lock=false"
```

### 11.8 Erro: EC2 não provisionado
```bash
make status
make provision
```

### 11.9 Erro: SSH connection refused
```bash
# Aguardar EC2 inicializar (2-3 minutos)
sleep 180
make status
```

### 11.10 Erro: Permission denied (publickey)
```bash
# Verificar chave SSH
ls -la ~/.ssh/terraform-dev.pem
chmod 400 ~/.ssh/terraform-dev.pem
```

### 11.11 Erro: Module not found
```bash
# Verificar MODULE_PATH
cat config.env | grep MODULE_PATH
ls -la $MODULE_PATH
```

### 11.12 Erro: "timeout while waiting for plugin to start" (macOS)

**Problema**: Testes locais falham com timeout no macOS

**Causa**: `terraform test` cria múltiplos subprocessos, cada um precisa reinicializar a cadeia de credenciais AWS. No macOS, isso causa timeouts frequentes devido a:
- Problemas na credential chain do AWS provider
- Configuração de rede com IPv6 link-local
- Memória insuficiente para múltiplos subprocessos

**Por que `terraform apply` funciona mas `terraform test` não?**
- `terraform apply`: Usa credenciais diretamente, processo único
- `terraform test`: Cria subprocessos para cada teste, cada um reinicializa credenciais

**Soluções**:

1. **Use `make remote-test` (recomendado)**
   ```bash
   make remote-test
   ```
   Funciona porque o EC2 tem IAM role anexado (não precisa de credential chain).

2. **Desabilitar IPv6 no macOS**
   - System Settings → Network → Advanced → TCP/IP
   - Configure IPv6: Off
   - Reiniciar máquina

3. **Usar variáveis de ambiente explícitas**
   ```bash
   AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy make test
   ```

**Referências oficiais**:
- [HashiCorp: Error timeout while waiting for plugin to start](https://support.hashicorp.com/hc/en-us/articles/18253685000083-Error-timeout-while-waiting-for-plugin-to-start)
- [HashiCorp: Terraform Run Hanging on macOS](https://support.hashicorp.com/hc/en-us/articles/9790957264915-Terraform-Run-Hanging-or-Timing-out-and-Network-Connection-failure-MacOS)

## 12. Métricas de Testes

### 12.1 Cobertura de Testes

Para o projeto terraform-dev-sandbox:
- **Total de recursos**: 14
- **Recursos testados**: 10
- **Cobertura**: 71%
- **Testes**: 15 passed, 0 failed

### 12.2 Tempo de Execução

Benchmarks típicos:
- **Primeira execução** (download de providers): ~30-60s
- **Execuções subsequentes** (com cache): ~5-15s
- **Pipeline completo** (`make remote-check`): ~2-5 minutos

### 12.3 Monitoramento de Testes

```bash
# Ver histórico de testes
make remote-exec CMD="cat ~/logs/test-*.log"

# Contar sucessos/falhas
make remote-exec CMD="grep -c 'Success!' ~/logs/test-*.log"

# Ver últimos erros
make remote-exec CMD="grep -A 5 'Error:' ~/logs/test-*.log | tail -20"
```

## 13. Integração Contínua

### 13.1 GitHub Actions

Exemplo de workflow para executar testes:

```yaml
name: Terraform Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.14.4
      
      - name: Terraform Init
        run: |
          cd tests
          terraform init
      
      - name: Terraform Test
        run: terraform test
```

### 13.2 GitLab CI

```yaml
test:
  image: hashicorp/terraform:1.14.4
  script:
    - cd tests && terraform init
    - cd .. && terraform test
  only:
    - merge_requests
    - main
```

## 14. Referências

- [Terraform Test Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Writing Terraform Tests](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)
- [Mock Providers](https://developer.hashicorp.com/terraform/language/tests/mocking)
- [Test Assertions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions)

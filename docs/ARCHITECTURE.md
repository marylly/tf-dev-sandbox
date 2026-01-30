# Architecture - Terraform Dev Sandbox

Detalhes técnicos da arquitetura do sistema.

## Visão Geral

Sistema de desenvolvimento distribuído que permite desenvolver módulos Terraform localmente e executar testes remotamente em um ambiente EC2 com acesso completo às APIs dos providers.

## Componentes

### 1. Notebook Local (Cliente)

**Responsabilidades**:
- Edição de código
- Controle de versão (git)
- Orquestração via Makefile
- Sincronização de arquivos

**Ferramentas**:
- Editor de código (VSCode, vim, etc)
- fswatch - Monitoramento de mudanças
- rsync - Sincronização incremental
- SSH - Conexão remota
- Make - Orquestração de comandos

**Estrutura**:
```
terraform-dev-sandbox/
├── infrastructure/     # Terraform para EC2
├── scripts/           # Scripts auxiliares
├── docs/              # Documentação
├── .ai/               # Memory bank
├── Makefile           # Comandos
└── config.env         # Configuração
```

### 2. Servidor EC2 (Sandbox)

**Responsabilidades**:
- Execução de Terraform
- Execução de testes
- Acesso às APIs dos providers
- Armazenamento de `.terraform/`
- Gerenciamento automático de versões do Terraform

**Ferramentas Instaladas**:
- tfenv (Terraform version manager)
- Terraform (gerenciado via tfenv)
- tfsec (security scanning)
- tflint (linting)
- terraform-docs (documentação)
- AWS CLI
- Git, Make, Python3, rsync

**tfenv - Gerenciamento de Versões**:

O tfenv detecta automaticamente a versão necessária do Terraform baseado em:
1. Arquivo `.terraform-version` no diretório do módulo
2. Campo `required_version` no `versions.tf`

Exemplo de uso automático:
```bash
# Módulo requer Terraform >= 1.5.0
# tfenv detecta e instala automaticamente
make remote-init  # tfenv install min-required && terraform init
```

Comandos tfenv disponíveis:
```bash
tfenv list              # Listar versões instaladas
tfenv install 1.14.4    # Instalar versão específica
tfenv use 1.14.4        # Usar versão específica
tfenv install latest    # Instalar versão mais recente
```

**Estrutura**:
```
/home/ec2-user/
├── workspace/         # Código sincronizado
│   ├── .terraform/    # Apenas aqui!
│   ├── main.tf
│   └── ...
├── logs/              # Logs de execução
└── README.txt         # Instruções
```

**Sistema Operacional**: Amazon Linux 2023

**Especificações**:
- Tipo: t3.medium (2 vCPU, 4GB RAM)
- Storage: 30GB GP3 (criptografado)
- Network: VPC pública com Internet Gateway

### 3. Infraestrutura AWS

**Recursos Criados**:

1. **VPC** (`vpc.tf`)
   - CIDR: 10.0.0.0/16
   - DNS habilitado
   - Subnet pública: 10.0.1.0/24

2. **Internet Gateway** (`internet-gateway.tf`)
   - Conecta VPC à internet
   - Route table para subnet pública

3. **Security Group** (`security-group.tf`)
   - Ingress: SSH (22) do seu IP
   - Egress restritivo:
     - HTTPS (443) - APIs dos providers
     - HTTP (80) - Downloads
     - DNS (53 UDP) - Resolução de nomes
     - NTP (123 UDP) - Sincronização de tempo

4. **IAM Role** (`iam.tf`)
   - Assume role para EC2
   - Políticas customizáveis
   - Instance Profile

5. **EC2 Instance** (`ec2.tf`)
   - AMI: Amazon Linux 2023
   - User data: Instala ferramentas
   - Key pair: SSH

## Fluxo de Dados

### Sincronização

```
┌─────────────┐
│   Notebook  │
│             │
│  1. Editar  │
│     código  │
└──────┬──────┘
       │
       │ 2. fswatch detecta mudança
       ▼
┌─────────────┐
│   fswatch   │
│             │
│  3. Trigger │
│     rsync   │
└──────┬──────┘
       │
       │ 4. rsync via SSH
       ▼
┌─────────────┐
│     EC2     │
│             │
│  5. Código  │
│  atualizado │
└─────────────┘
```

### Execução de Testes

```
┌─────────────┐
│   Notebook  │
│             │
│  1. make    │
│  remote-    │
│  test       │
└──────┬──────┘
       │
       │ 2. Sync + Init tests/
       ▼
┌─────────────┐
│     EC2     │
│             │
│  3. cd      │
│  tests &&   │
│  terraform  │
│  init       │
└──────┬──────┘
       │
       │ 4. Execute terraform test
       ▼
┌─────────────┐
│     EC2     │
│             │
│  5. Run     │
│  .tftest    │
│  .hcl files │
└──────┬──────┘
       │
       │ 6. Resultados via SSH
       ▼
┌─────────────┐
│   Notebook  │
│             │
│  7. Exibir  │
│  passed/    │
│  failed     │
└─────────────┘
```

**Tipos de Testes Suportados**:

1. **terraform test (tftest)**
   - Testes unitários com mocks
   - Testes de integração
   - Validação de outputs
   - Localização: `tests/*.tftest.hcl`

2. **tfsec**
   - Security scanning
   - Detecção de vulnerabilidades
   - Best practices

3. **tflint**
   - Linting de código
   - Validação de sintaxe
   - Detecção de erros

4. **terraform validate**
   - Validação de configuração
   - Verificação de sintaxe

## Decisões de Design

### 0. Por que terraform test (tftest)?

**Decisão**: Usar terraform test nativo para testes unitários

**Razões**:
- Nativo do Terraform (1.6+)
- Suporta mocks de providers
- Testes rápidos sem criar recursos reais
- Sintaxe HCL familiar
- Integração com CI/CD

**Estrutura de Testes**:
```
module/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── unit-test-1.tftest.hcl
    ├── unit-test-2.tftest.hcl
    └── integration-test.tftest.hcl
```

**Exemplo de Teste**:
```hcl
# tests/unit-vpc.tftest.hcl
run "validate_vpc_configuration" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR incorreto"
  }
}
```

**Fluxo de Execução**:
1. `make remote-test` sincroniza código
2. Executa `terraform init` na pasta `tests/`
3. Executa `terraform test` no diretório raiz
4. Terraform procura arquivos `*.tftest.hcl` em `tests/`
5. Executa cada bloco `run` sequencialmente
6. Retorna resultados (passed/failed/skipped)

**Alternativas Consideradas**:
- Terratest (Go): Mais complexo, requer Go
- Kitchen-Terraform: Dependência Ruby
- Testes manuais: Não automatizável

### 1. Por que Repositório Separado?

**Decisão**: Infraestrutura em repositório separado do módulo

**Razões**:
- Reutilizável para qualquer módulo
- Não polui repositório do módulo
- Fácil de atualizar
- Configurável via `config.env`

**Alternativas Consideradas**:
- Integrar no repositório do módulo: Polui o repo
- Usar Docker: Não resolve bloqueio de APIs

### 2. Por que rsync + fswatch?

**Decisão**: rsync para sincronização, fswatch para monitoramento

**Razões**:
- Simples e confiável
- Incremental (apenas mudanças)
- Disponível nativamente no macOS
- Baixa latência (~1-2s)

**Alternativas Consideradas**:
- VS Code Remote SSH: Problemas com extensões
- Mutagen: Dependência adicional
- NFS/SSHFS: Performance ruim

### 3. Por que EC2 e não Lambda/Fargate?

**Decisão**: EC2 com estado persistente

**Razões**:
- Terraform precisa de ambiente stateful
- `.terraform/` pode ser grande (GB)
- Cache de providers persiste
- Debugging interativo mais fácil
- Suporta qualquer provider

**Alternativas Consideradas**:
- Lambda: Sem estado, timeout curto
- Fargate: Mais caro, menos flexível
- CodeBuild: Focado em CI/CD

### 4. Por que Um Arquivo .tf por Recurso?

**Decisão**: Arquivos separados por tipo de recurso

**Razões**:
- Fácil localização de código
- Melhor organização
- Facilita code review
- Evita arquivos gigantes

**Estrutura**:
```
infrastructure/
├── vpc.tf              # Rede
├── security-group.tf   # Firewall
├── iam.tf              # Permissões
├── ec2.tf              # Computação
└── ...
```

### 5. Por que Makefile?

**Decisão**: Makefile para orquestração

**Razões**:
- Simples e universal
- Não requer instalação
- Fácil de entender
- Suporta dependências

**Alternativas Consideradas**:
- Scripts bash: Menos estruturado
- Task runners (npm, etc): Dependência extra
- CLI customizado: Complexidade desnecessária

### 6. Por que Segurança Simples?

**Decisão**: Sem Secrets Manager, CloudTrail

**Razões**:
- Ambiente de desenvolvimento, não produção
- Reduz complexidade
- Reduz custos
- IAM Role suficiente

**Nota**: Para produção, adicionar:
- AWS Secrets Manager
- CloudTrail
- VPC privada
- Bastion host

## Segurança

### Modelo de Ameaças

**Ameaças Consideradas**:
1. Acesso não autorizado ao EC2
2. Exposição de credenciais AWS
3. Execução de código malicioso
4. Vazamento de dados sensíveis

**Mitigações**:

1. **Acesso SSH Restrito**
   - Security Group limita ao seu IP
   - Chave SSH privada
   - Sem senha

2. **Credenciais AWS**
   - IAM Role (não access keys)
   - Princípio de menor privilégio
   - Sem credenciais no código

3. **Código Malicioso**
   - Você controla o código sincronizado
   - Revisar módulos de terceiros
   - Executar em ambiente isolado

4. **Dados Sensíveis**
   - Não sincronizar `.tfvars` com secrets
   - Usar variáveis de ambiente
   - `.gitignore` configurado

### Boas Práticas

**1. Security Group Restritivo**

O Security Group implementa o princípio de menor privilégio:

```hcl
# Apenas protocolos necessários
egress {
  from_port   = 443  # HTTPS
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  from_port   = 80   # HTTP
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  from_port   = 53   # DNS
  to_port     = 53
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  from_port   = 123  # NTP
  to_port     = 123
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**Protocolos bloqueados**: SMTP, SMB, RDP, FTP, Telnet, etc.

**2. Rotação de Chaves SSH**
   ```bash
   # Gerar nova chave
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/terraform-dev-new.pem
   
   # Atualizar Terraform
   # Reprovisionar EC2
   ```

**3. Auditoria**
   ```bash
   # Ver logs de SSH
   make remote-exec CMD="sudo cat /var/log/secure"
   
   # Ver comandos executados
   make remote-exec CMD="history"
   ```

**4. Limpeza**
   ```bash
   # Destruir quando não precisar
   make destroy
   
   # Limpar credenciais locais
   rm -f ~/.ssh/terraform-dev.pem*
   ```

## Performance

### Otimizações Implementadas

1. **Sincronização Incremental**
   - rsync sincroniza apenas mudanças
   - Compressão habilitada (`-z`)
   - Exclusões configuradas

2. **Cache de Providers**
   - `.terraform/` persiste no EC2
   - Providers baixados uma vez
   - Reduz tempo de `terraform init`

3. **Instância Adequada**
   - t3.medium: 2 vCPU, 4GB RAM
   - Suficiente para maioria dos casos
   - Escalável se necessário

### Benchmarks

**Sincronização** (módulo típico ~50 arquivos):
- Primeira vez: ~5-10s
- Incremental: ~1-2s

**Terraform Init** (3-4 providers):
- Primeira vez: ~30-60s
- Com cache: ~5-10s

**Terraform Plan** (10-20 recursos):
- ~10-30s

**Pipeline Completo** (`make remote-check`):
- ~2-5 minutos

## Escalabilidade

### Limitações Atuais

1. **Single User**: Um desenvolvedor por vez
2. **Single Module**: Um módulo por vez
3. **Single Region**: Uma região AWS

### Possíveis Extensões

1. **Multi-User**
   - Múltiplas instâncias EC2
   - Load balancer
   - Workspaces isolados

2. **Multi-Module**
   - Múltiplos workspaces no EC2
   - Sincronização paralela
   - Isolamento de `.terraform/`

3. **Multi-Region**
   - Replicar infraestrutura
   - Failover automático
   - Latência reduzida

## Monitoramento

### Métricas Importantes

1. **EC2**
   - CPU utilization
   - Memory utilization
   - Disk usage
   - Network in/out

2. **Sincronização**
   - Tempo de sync
   - Tamanho transferido
   - Erros de conexão

3. **Testes**
   - Tempo de execução
   - Taxa de sucesso
   - Cobertura

### Como Monitorar

```bash
# Status do EC2
make status

# Uso de disco no EC2
make remote-exec CMD="df -h"

# Uso de memória
make remote-exec CMD="free -h"

# Processos rodando
make remote-exec CMD="top -b -n 1"

# Logs
make remote-exec CMD="tail -f ~/logs/*.log"
```

## Custos

### Breakdown Mensal

| Recurso | Custo Estimado |
|---------|----------------|
| EC2 t3.medium (on-demand) | $30.37 |
| EBS 30GB GP3 | $2.40 |
| Data Transfer | $1-5 |
| **Total** | **~$32-37** |

### Otimizações de Custo

1. **Usar Spot Instances**
   - Economia de ~70%
   - Risco de interrupção

2. **Parar Quando Não Usar**
   ```bash
   make stop  # Fim do dia
   make start # Próximo dia
   ```
   - Economia: ~$20/mês

3. **Instância Menor**
   - t3.small: $15/mês
   - Para testes leves

## Manutenção

### Atualizações

**Terraform** (gerenciado via tfenv):
```bash
# Instalar nova versão
make remote-exec CMD="tfenv install 1.14.4"

# Usar nova versão
make remote-exec CMD="tfenv use 1.14.4"

# Instalar versão mais recente
make remote-exec CMD="tfenv install latest && tfenv use latest"

# Listar versões disponíveis
make remote-exec CMD="tfenv list-remote"
```

**tfenv** (atualizar o próprio tfenv):
```bash
make remote-exec CMD="cd ~/.tfenv && git pull"
```

**Ferramentas**:
```bash
# tfsec
make remote-exec CMD="wget https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64 -O /tmp/tfsec"
make remote-exec CMD="sudo mv /tmp/tfsec /usr/local/bin/ && sudo chmod +x /usr/local/bin/tfsec"

# tflint
make remote-exec CMD="curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
```

### Backup

**Importante**: Não há backup automático!

**O que fazer**:
1. Código está no seu módulo (git)
2. Infraestrutura é código (Terraform)
3. EC2 é efêmero (pode recriar)

**Se precisar backup**:
```bash
# Backup do workspace
make remote-exec CMD="tar -czf ~/backup.tar.gz ~/workspace/"
scp -i ~/.ssh/terraform-dev.pem ec2-user@$(make status | grep EC2 | awk '{print $3}'):~/backup.tar.gz .
```

## Referências

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [rsync Manual](https://linux.die.net/man/1/rsync)
- [fswatch Documentation](https://github.com/emcrisostomo/fswatch)

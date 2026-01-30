# Terraform Dev Sandbox

Ambiente de desenvolvimento Terraform com sincronização automática para EC2.

## Problema

Desenvolver módulos Terraform localmente quando as APIs dos cloud providers estão bloqueadas (firewall corporativo, VPN, etc.) é impossível - comandos como `terraform plan` e `terraform apply` falham sem acesso às APIs.

## Solução

Este repositório provisiona um EC2 na AWS com acesso total às APIs, sincroniza seu código automaticamente, e permite executar todos os comandos Terraform remotamente. Você desenvolve localmente, o código é sincronizado em tempo real, e os testes rodam no EC2.

**Recursos principais**:
- 🔄 Sincronização automática de código (rsync + fswatch)
- 🔧 tfenv para gerenciamento automático de versões do Terraform
- 🧪 Execução remota de testes (terraform test/tftest, tfsec, tflint)
- ⚡ Provisionamento automatizado com `-auto-approve`

## Quick Start

```bash
# 1. Clone e configure
git clone <repo> terraform-dev-sandbox
cd terraform-dev-sandbox
make setup

# 2. Configure variáveis interativamente
make configure  # Configura MODULE_PATH, MY_IP e AWS_REGION

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
make test           # Executar testes localmente
make remote-check   # Executar todos os testes no EC2
make stop           # Parar EC2
make destroy        # Destruir tudo
```

**Nota sobre testes locais**: `make test` executa testes do módulo localmente, mas pode falhar no macOS com timeout devido a problemas na cadeia de credenciais AWS. Use `make remote-test` para executar testes no EC2 (funciona porque o EC2 tem IAM role anexado).

**Por que isso acontece?** `terraform test` cria múltiplos subprocessos (um por teste), e cada um precisa reinicializar a cadeia de credenciais. No macOS, isso pode causar timeouts. Veja [documentação oficial da HashiCorp](https://support.hashicorp.com/hc/en-us/articles/18253685000083-Error-timeout-while-waiting-for-plugin-to-start) sobre o problema.

## Documentação

Veja [docs/](docs/) para documentação completa:
- [Setup](docs/SETUP.md) - Configuração detalhada
- [Testing](docs/TESTING.md) - Guia de testes
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Resolução de problemas
- [Architecture](docs/ARCHITECTURE.md) - Detalhes técnicos
- [Contributing](docs/CONTRIBUTING.md) - Como contribuir

## Licença

MIT

# Contributing - Terraform Dev Sandbox

Obrigado por considerar contribuir para o Terraform Dev Sandbox!

## Quick Start para Contribuidores

Configure seu ambiente local em 3 passos:

```bash
# 1. Clone e configure
git clone <repo-url>
cd terraform-dev-sandbox
make setup

# 2. Configure variáveis (interativo)
make configure

# 3. Provisione e teste
make provision
make test
```

Pronto! Agora você pode fazer suas mudanças e testar localmente.

---

## Como Contribuir

### Reportar Bugs

Encontrou um bug? Abra uma issue com:

1. **Título claro**: Descreva o problema em uma linha
2. **Descrição detalhada**: O que aconteceu vs o que era esperado
3. **Passos para reproduzir**: Como reproduzir o bug
4. **Ambiente**: SO, versões de ferramentas
5. **Logs**: Saída de comandos relevantes

**Exemplo**:
```
Título: make sync falha com "Permission denied"

Descrição:
Ao executar `make sync`, recebo erro "Permission denied" mesmo com chave SSH configurada.

Passos para reproduzir:
1. make setup
2. make provision
3. make sync

Ambiente:
- macOS 13.0
- Terraform 1.7.0
- rsync 3.2.7

Logs:
Permission denied (publickey).
rsync: connection unexpectedly closed
```

### Sugerir Features

Tem uma ideia? Abra uma issue com:

1. **Título claro**: Descreva a feature
2. **Problema**: Que problema resolve?
3. **Solução proposta**: Como funcionaria?
4. **Alternativas**: Outras abordagens consideradas?
5. **Contexto adicional**: Screenshots, exemplos, etc

### Pull Requests

1. **Fork** o repositório
2. **Crie um branch** para sua feature (`git checkout -b feat/minha-feature`)
3. **Faça commits** seguindo convenções
4. **Teste** suas mudanças
5. **Push** para seu fork
6. **Abra um Pull Request**

## Padrões de Código

### Terraform

**Formatação**:
```bash
terraform fmt -recursive
```

**Validação**:
```bash
terraform validate
```

**Linting**:
```bash
tflint --recursive
```

**Estrutura**:
- Um arquivo `.tf` por tipo de recurso
- Nomenclatura: `vpc.tf`, `ec2.tf`, `iam.tf`
- Não usar `main.tf` monolítico

**Variáveis**:
- snake_case: `instance_type`, `vpc_cidr`
- Sempre incluir `description`
- Incluir `default` quando apropriado
- Usar `validation` quando possível

**Exemplo**:
```hcl
variable "instance_type" {
  description = "Tipo de instância EC2"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Apenas instâncias t3.* são suportadas"
  }
}
```

### Makefile

**Regras**:
- Todos os targets devem usar `.PHONY`
- Mensagens claras de erro e sucesso
- Validar pré-condições
- Incluir no `help`

**Exemplo**:
```makefile
.PHONY: meu-comando
meu-comando:
	@echo "Executando meu comando..."
	@if [ -z "$(VARIAVEL)" ]; then \
		echo "Erro: VARIAVEL não definida"; \
		exit 1; \
	fi
	# Comando aqui
	@echo "✓ Comando concluído"
```

### Bash Scripts

**Regras**:
- Sempre usar `set -e` (parar em erro)
- Validar pré-requisitos
- Mensagens claras de progresso
- Comentários explicativos

**Exemplo**:
```bash
#!/bin/bash
set -e

echo "=== Meu Script ==="

# Verificar dependência
if ! command -v ferramenta &> /dev/null; then
    echo "❌ ferramenta não encontrada"
    exit 1
fi

echo "✓ Dependências OK"

# Executar ação
echo "Executando ação..."
# código aqui

echo "✓ Concluído"
```

### Documentação

**Markdown**:
- Títulos claros e hierárquicos
- Exemplos de código com syntax highlighting
- Links para referências
- Tabelas para comparações

**README.md**:
- Minimalista (< 50 linhas)
- Quick start em 5 passos
- Links para docs/

**docs/**:
- Documentação detalhada
- Exemplos práticos
- Troubleshooting

## Convenções de Commit

Seguimos [Conventional Commits](https://www.conventionalcommits.org/):

**Formato**:
```
<tipo>(<escopo>): <descrição>

[corpo opcional]

[rodapé opcional]
```

**Tipos**:
- `feat`: Nova funcionalidade
- `fix`: Correção de bug
- `docs`: Mudanças em documentação
- `style`: Formatação, sem mudança de código
- `refactor`: Refatoração de código
- `test`: Adição ou modificação de testes
- `chore`: Tarefas de manutenção

**Exemplos**:
```
feat(makefile): adicionar comando remote-logs

Adiciona comando para visualizar logs do EC2 remotamente.

Closes #123
```

```
fix(sync): corrigir exclusão de .terraform/

O rsync não estava excluindo corretamente a pasta .terraform/,
causando sincronização lenta.
```

```
docs(setup): atualizar guia de instalação

Adiciona instruções para macOS Apple Silicon.
```

## Processo de Review

### O que Revisamos

1. **Funcionalidade**: Funciona como esperado?
2. **Testes**: Está testado?
3. **Documentação**: Está documentado?
4. **Código**: Segue padrões?
5. **Commits**: Seguem convenções?

### Checklist do PR

Antes de abrir PR, verifique:

- [ ] Código funciona localmente
- [ ] Testes passam
- [ ] Documentação atualizada
- [ ] Commits seguem convenções
- [ ] Sem conflitos com main
- [ ] PR tem descrição clara

### Exemplo de Descrição de PR

```markdown
## Descrição
Adiciona suporte para instâncias ARM (Graviton).

## Motivação
Instâncias ARM são mais baratas e eficientes.

## Mudanças
- Adiciona variável `architecture` em `variables.tf`
- Atualiza AMI data source para suportar ARM
- Atualiza documentação

## Testes
- [x] Testado em t4g.medium (ARM)
- [x] Testado em t3.medium (x86)
- [x] Documentação revisada

## Checklist
- [x] Código funciona
- [x] Testes passam
- [x] Documentação atualizada
- [x] Commits convencionais
```

## Testes

### Testes Manuais

Antes de submeter PR:

```bash
# 1. Setup
make setup

# 2. Provisionar
make provision

# 3. Testar sincronização
make sync

# 4. Testar comandos remotos
make remote-shell
make remote-check

# 5. Testar stop/start
make stop
make start

# 6. Limpar
make destroy
```

### Testes Automatizados

(Futuro: CI/CD com GitHub Actions)

## Estrutura do Projeto

```
terraform-dev-sandbox/
├── infrastructure/        # Terraform
│   ├── vpc.tf
│   ├── ec2.tf
│   └── ...
├── scripts/              # Scripts auxiliares
│   └── setup.sh
├── docs/                 # Documentação
│   ├── SETUP.md
│   ├── TESTING.md
│   ├── TROUBLESHOOTING.md
│   └── ...
├── .ai/                  # Memory bank
│   └── memory/
│       └── codebase.md
├── Makefile              # Comandos
├── config.env.example    # Exemplo de config
├── .gitignore
├── .ai-rules             # Regras para IA
└── README.md
```

## Áreas para Contribuir

### Fácil (Good First Issue)

- Melhorar documentação
- Adicionar exemplos
- Corrigir typos
- Melhorar mensagens de erro

### Médio

- Adicionar novos comandos no Makefile
- Melhorar scripts de setup
- Adicionar suporte para outras ferramentas
- Otimizações de performance

### Difícil

- Suporte para múltiplos usuários
- Suporte para Windows/Linux
- CI/CD automatizado
- Monitoramento e métricas

## Código de Conduta

### Nossos Padrões

**Comportamentos Esperados**:
- Ser respeitoso e inclusivo
- Aceitar críticas construtivas
- Focar no que é melhor para a comunidade
- Mostrar empatia

**Comportamentos Inaceitáveis**:
- Linguagem ofensiva ou discriminatória
- Assédio público ou privado
- Publicar informações privadas de outros
- Conduta não profissional

### Aplicação

Violações podem resultar em:
1. Aviso
2. Banimento temporário
3. Banimento permanente

Reporte violações para: [email]

## Perguntas?

- Abra uma issue com a tag `question`
- Entre em contato: [email]
- Leia a documentação: [docs/](.)

## Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a mesma licença do projeto (MIT).

## Agradecimentos

Obrigado a todos os contribuidores! 🎉

Contribuidores principais:
- [Lista de contribuidores]

## Recursos Úteis

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

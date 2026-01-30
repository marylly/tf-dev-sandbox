# Carregar configurações do arquivo config.env (se existir)
-include config.env

# Configuração
EC2_IP := $(shell AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infrastructure output -raw ec2_ip 2>/dev/null || echo "")
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
	@$(MAKE) remote-exec CMD="tfenv install min-required && terraform init"

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

.PHONY: remote-test
remote-test: sync
	@echo "Executando testes com tftest no EC2..."
	@$(MAKE) remote-exec CMD="(cd tests) && terraform init && terraform test"

.PHONY: remote-tfsec
remote-tfsec: sync
	@echo "Executando tfsec no EC2..."
	@$(MAKE) remote-exec CMD="tfsec ."

.PHONY: remote-lint
remote-lint: sync
	@echo "Executando tflint no EC2..."
	@$(MAKE) remote-exec CMD="tflint --recursive"

.PHONY: remote-check
remote-check: sync remote-fmt remote-validate remote-lint remote-tfsec remote-test
	@echo "✓ Todas as verificações passaram!"

# Testes locais do módulo (requer credenciais AWS configuradas)
# Nota: pode falhar no macOS com timeout devido a problemas na cadeia de credenciais
# Workaround: use 'make remote-test' para executar testes no EC2
.PHONY: test
test:
	@echo "Executando testes do módulo localmente..."
	@if [ ! -d "$(MODULE_PATH)" ]; then \
		echo "Erro: Módulo não encontrado em $(MODULE_PATH)"; \
		exit 1; \
	fi
	@if [ ! -d "$(MODULE_PATH)/tests" ]; then \
		echo "Erro: Diretório de testes não encontrado em $(MODULE_PATH)/tests"; \
		exit 1; \
	fi
	@cd $(MODULE_PATH)/tests && AWS_PROFILE=$(AWS_PROFILE) terraform init
	@cd $(MODULE_PATH) && AWS_PROFILE=$(AWS_PROFILE) terraform test

.PHONY: test-verbose
test-verbose:
	@echo "Executando testes do módulo localmente (modo verbose)..."
	@if [ ! -d "$(MODULE_PATH)" ]; then \
		echo "Erro: Módulo não encontrado em $(MODULE_PATH)"; \
		exit 1; \
	fi
	@if [ ! -d "$(MODULE_PATH)/tests" ]; then \
		echo "Erro: Diretório de testes não encontrado em $(MODULE_PATH)/tests"; \
		exit 1; \
	fi
	@cd $(MODULE_PATH)/tests && AWS_PROFILE=$(AWS_PROFILE) terraform init
	@cd $(MODULE_PATH) && AWS_PROFILE=$(AWS_PROFILE) terraform test -verbose

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
		echo "⚠️  Configure o MODULE_PATH e MY_IP no arquivo config.env"; \
	fi
	@echo "✓ Ambiente configurado"
	@echo ""
	@echo "Próximo passo: execute 'make configure' para configurar variáveis"

.PHONY: configure
configure:
	@echo "=== Configuração de Variáveis de Ambiente ==="
	@echo ""
	@if [ ! -f "config.env" ]; then \
		echo "Criando config.env..."; \
		cp config.env.example config.env; \
	fi
	@echo "1. Obtendo seu IP público..."
	@MY_IP_DETECTED=$$(curl -s https://ifconfig.me 2>/dev/null || echo ""); \
	if [ -n "$$MY_IP_DETECTED" ]; then \
		echo "   IP detectado: $$MY_IP_DETECTED"; \
		read -p "   Usar este IP? (y/n): " use_ip; \
		if [ "$$use_ip" = "y" ]; then \
			sed -i.bak "s|MY_IP=.*|MY_IP=$$MY_IP_DETECTED/32|" config.env && rm config.env.bak; \
			echo "   ✓ MY_IP configurado"; \
		else \
			read -p "   Digite seu IP: " custom_ip; \
			sed -i.bak "s|MY_IP=.*|MY_IP=$$custom_ip/32|" config.env && rm config.env.bak; \
			echo "   ✓ MY_IP configurado"; \
		fi; \
	else \
		echo "   ⚠️  Não foi possível detectar IP automaticamente"; \
		read -p "   Digite seu IP: " custom_ip; \
		sed -i.bak "s|MY_IP=.*|MY_IP=$$custom_ip/32|" config.env && rm config.env.bak; \
		echo "   ✓ MY_IP configurado"; \
	fi
	@echo ""
	@echo "2. Configurando MODULE_PATH..."
	@read -p "   Digite o caminho completo do seu módulo Terraform: " module_path; \
	if [ -d "$$module_path" ]; then \
		sed -i.bak "s|MODULE_PATH=.*|MODULE_PATH=$$module_path|" config.env && rm config.env.bak; \
		echo "   ✓ MODULE_PATH configurado: $$module_path"; \
	else \
		echo "   ⚠️  Diretório não encontrado: $$module_path"; \
		echo "   Configurando mesmo assim..."; \
		sed -i.bak "s|MODULE_PATH=.*|MODULE_PATH=$$module_path|" config.env && rm config.env.bak; \
	fi
	@echo ""
	@echo "3. Configurando AWS_REGION..."
	@read -p "   Digite a região AWS (padrão: us-east-1): " aws_region; \
	if [ -z "$$aws_region" ]; then \
		aws_region="us-east-1"; \
	fi; \
	sed -i.bak "s|AWS_REGION=.*|AWS_REGION=$$aws_region|" config.env && rm config.env.bak; \
	echo "   ✓ AWS_REGION configurado: $$aws_region"
	@echo ""
	@echo "4. Configurando AWS_PROFILE..."
	@read -p "   Digite o AWS profile (padrão: default): " aws_profile; \
	if [ -z "$$aws_profile" ]; then \
	aws_profile="default"; \
	fi; \
	sed -i.bak "s|AWS_PROFILE=.*|AWS_PROFILE=$$aws_profile|" config.env && rm config.env.bak; \
echo "   ✓ AWS_PROFILE configurado: $$aws_profile"
	@echo ""
	@echo "=== Configuração Completa ==="
	@echo ""
	@echo "Arquivo config.env atualizado:"
	@cat config.env
	@echo ""
	@echo "Próximo passo: execute 'make provision' para criar a infraestrutura"

.PHONY: provision
provision:
	@echo "Provisionando infraestrutura EC2..."
	@rm -f infrastructure/.terraform.tfstate.lock.info
	@if [ -z "$(MY_IP)" ]; then \
		echo "Erro: MY_IP não configurado no config.env"; \
		echo "Configure MY_IP com seu IP público (formato: SEU_IP/32)"; \
		echo "Obtenha seu IP em: curl https://ifconfig.me"; \
		exit 1; \
	fi
	AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infrastructure init
	AWS_PROFILE=$(AWS_PROFILE) TF_VAR_aws_region=$(AWS_REGION) terraform -chdir=infrastructure apply -auto-approve -var="my_ip=$(MY_IP)" -lock-timeout=5m -lock=false
	@echo "✓ Infraestrutura provisionada"
	@echo "IP do EC2: $$(AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infrastructure output -raw ec2_ip)"

.PHONY: stop
stop:
	@echo "Parando instância EC2..."
	@TF_VAR_aws_region=$(AWS_REGION) terraform -chdir=infrastructure apply -auto-approve -var="instance_state=stopped" -lock=false
	@echo "✓ Instância EC2 parada"

.PHONY: start
start:
	@echo "Iniciando instância EC2..."
	@TF_VAR_aws_region=$(AWS_REGION) terraform -chdir=infrastructure apply -auto-approve -var="instance_state=running" -lock-timeout=5m
	@echo "✓ Instância EC2 iniciada"
	@echo "IP do EC2: $$(AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infrastructure output -raw ec2_ip)"

.PHONY: destroy
destroy:
	@echo "Destruindo infraestrutura EC2..."
	AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infrastructure destroy -auto-approve -lock=false
	@echo "✓ Infraestrutura destruída"
	@$(MAKE) clean

# Comandos de limpeza
.PHONY: clean
clean:
	@echo "Limpando arquivos locais do Terraform..."
	@rm -rf infrastructure/.terraform/
	@rm -f infrastructure/.terraform.lock.hcl
	@rm -f infrastructure/terraform.tfstate*
	@rm -f infrastructure/.terraform.tfstate.lock.info
	@echo "✓ Arquivos locais limpos"

.PHONY: clean-remote
clean-remote:
	@echo "Limpando arquivos temporários no EC2..."
	@$(MAKE) remote-exec CMD="rm -rf .terraform/ *.tfstate* .terraform.lock.hcl"

# Status
.PHONY: status
status:
	@echo "Status do ambiente:"
	@echo "  Módulo: $(MODULE_PATH)"
	@EC2_ID=$$(AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infrastructure output -raw ec2_id 2>/dev/null); \
	if [ -z "$$EC2_ID" ]; then \
		echo "  EC2: Não provisionado"; \
	else \
		EC2_INFO=$$(AWS_PROFILE=$(AWS_PROFILE) aws ec2 describe-instances --instance-ids $$EC2_ID --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]' --output text 2>/dev/null); \
		EC2_STATE=$$(echo "$$EC2_INFO" | awk '{print $$1}'); \
		EC2_IP=$$(echo "$$EC2_INFO" | awk '{print $$2}'); \
		echo "  EC2: Provisionado ($$EC2_IP)"; \
		echo "  Estado: $$EC2_STATE"; \
		if [ "$$EC2_STATE" = "running" ]; then \
			ssh -i $(SSH_KEY) -o ConnectTimeout=5 $(REMOTE_USER)@$$EC2_IP "echo '  Conexão: OK'" 2>/dev/null || echo "  Conexão: FALHOU"; \
		fi; \
	fi

# Help
.PHONY: help
help:
	@echo "Terraform Dev Sandbox - Comandos disponíveis:"
	@echo ""
	@echo "Setup:"
	@echo "  make setup          - Configura ambiente local (instala fswatch)"
	@echo "  make configure      - Configura variáveis de ambiente interativamente"
	@echo "  make provision      - Provisiona infraestrutura EC2"
	@echo "  make start          - Inicia instância EC2 (se parada)"
	@echo "  make stop           - Para instância EC2"
	@echo "  make destroy        - Destrói TODA a infraestrutura"
	@echo ""
	@echo "Sincronização:"
	@echo "  make sync           - Sincroniza código do módulo uma vez"
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
	@echo "  make test           - Executa testes do módulo localmente"
	@echo "  make test-verbose   - Executa testes do módulo localmente (verbose)"
	@echo "  make remote-test    - Executa testes do módulo no EC2"
	@echo "  make remote-tfsec   - Executa tfsec (security) no módulo"
	@echo "  make remote-lint    - Executa tflint no módulo"
	@echo "  make remote-check   - Executa todas as verificações no módulo"
	@echo ""
	@echo "Utilitários:"
	@echo "  make status         - Mostra status do ambiente"
	@echo "  make clean          - Limpa arquivos locais do Terraform"
	@echo "  make clean-remote   - Limpa arquivos temporários no EC2"

# Troubleshooting - Terraform Dev Sandbox

Soluções para problemas comuns.

## Problemas de Conexão SSH

### Erro: Permission denied (publickey)

**Sintomas**:
```
Permission denied (publickey).
```

**Causas**:
1. Chave SSH não existe
2. Permissões incorretas
3. Chave não configurada no EC2

**Soluções**:

```bash
# Verificar se chave existe
ls -la ~/.ssh/terraform-dev.pem

# Se não existir, gerar
ssh-keygen -t rsa -b 4096 -f ~/.ssh/terraform-dev.pem -N ""

# Corrigir permissões
chmod 400 ~/.ssh/terraform-dev.pem
chmod 400 ~/.ssh/terraform-dev.pem.pub

# Reprovisionar EC2
cd infrastructure
terraform taint aws_instance.dev
terraform apply
```

### Erro: Connection timed out

**Sintomas**:
```
ssh: connect to host X.X.X.X port 22: Connection timed out
```

**Causas**:
1. Security Group bloqueando seu IP
2. EC2 não iniciado completamente
3. IP mudou ao reiniciar EC2 (comportamento normal)

**Soluções**:

```bash
# 1. Verificar seu IP atual
curl https://ifconfig.me

# 2. Atualizar terraform.tfvars
vim infrastructure/terraform.tfvars
# my_ip = "SEU_NOVO_IP/32"

# 3. Aplicar mudanças
cd infrastructure
terraform apply

# 4. Aguardar EC2 inicializar (2-3 minutos após provision)
make status

# 5. Testar conexão
make remote-shell
```

### Erro: Host key verification failed

**Sintomas**:
```
Host key verification failed.
```

**Causa**: IP do EC2 mudou e SSH detectou mudança

**Solução**:
```bash
# Remover entrada antiga do known_hosts
ssh-keygen -R $(cd infrastructure && terraform output -raw ec2_ip)

# Tentar novamente
make remote-shell
```

## Problemas de Sincronização

### Erro: rsync: command not found

**Sintomas**:
```
rsync: command not found
```

**Solução**:
```bash
# macOS (geralmente pré-instalado)
which rsync

# Se não encontrado, instalar
brew install rsync
```

### Erro: fswatch: command not found

**Sintomas**:
```
fswatch: command not found
```

**Solução**:
```bash
# Instalar fswatch
brew install fswatch

# Verificar instalação
fswatch --version
```

### Sincronização Muito Lenta

**Sintomas**: `make sync` demora muito

**Causas**:
1. Muitos arquivos
2. Arquivos grandes
3. `.terraform/` sendo sincronizado

**Soluções**:

```bash
# 1. Verificar se .terraform/ está sendo excluído
# Deve estar no Makefile:
# --exclude='.terraform/'

# 2. Adicionar mais exclusões se necessário
# Editar Makefile, adicionar:
# --exclude='node_modules/' \
# --exclude='*.zip' \
# --exclude='vendor/'

# 3. Limpar .terraform/ local (não deveria existir)
cd $MODULE_PATH
rm -rf .terraform/
```

### Watch Não Detecta Mudanças

**Sintomas**: Salvar arquivo não sincroniza

**Causas**:
1. fswatch não rodando
2. Caminho incorreto
3. Editor salvando de forma especial

**Soluções**:

```bash
# 1. Verificar se watch está rodando
ps aux | grep fswatch

# 2. Parar e reiniciar watch
# Ctrl+C no terminal do watch
make watch

# 3. Testar sincronização manual
make sync

# 4. Verificar MODULE_PATH
cat config.env | grep MODULE_PATH
ls -la $MODULE_PATH
```

## Problemas de Terraform

### Erro: EC2 não provisionado

**Sintomas**:
```
Erro: EC2 não provisionado. Execute 'make provision' primeiro
```

**Solução**:
```bash
# Provisionar infraestrutura
make provision

# Verificar status
make status
```

### Erro: terraform.tfvars não configurado

**Sintomas**:
```
Error: Missing required argument
The argument "my_ip" is required
```

**Solução**:
```bash
# Criar terraform.tfvars
cd infrastructure
cp terraform.tfvars.example terraform.tfvars

# Editar e configurar my_ip
vim terraform.tfvars

# Obter seu IP
curl https://ifconfig.me

# Aplicar
terraform apply
```

### Erro: AWS credentials not found

**Sintomas**:
```
Error: error configuring Terraform AWS Provider
```

**Solução**:
```bash
# Configurar AWS CLI
aws configure

# Verificar credenciais
aws sts get-caller-identity

# Se usar perfis
export AWS_PROFILE=seu-perfil
```

### Erro: Insufficient permissions

**Sintomas**:
```
Error: creating EC2 Instance: UnauthorizedOperation
```

**Causa**: Credenciais AWS sem permissões necessárias

**Solução**:
1. Verificar permissões IAM do usuário AWS
2. Necessário permissões para: EC2, VPC, IAM
3. Contatar administrador AWS se necessário

## Problemas no EC2

### Ferramentas Não Instaladas

**Sintomas**:
```
terraform: command not found
tfsec: command not found
```

**Causa**: user-data não executou corretamente

**Soluções**:

```bash
# 1. Conectar ao EC2
make remote-shell

# 2. Verificar log do user-data
sudo cat /var/log/user-data.log

# 3. Se houver erros, reinstalar manualmente
# Terraform
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# tfsec
wget https://github.com/aquasecurity/tfsec/releases/download/v1.28.5/tfsec-linux-amd64
chmod +x tfsec-linux-amd64
sudo mv tfsec-linux-amd64 /usr/local/bin/tfsec

# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# 4. Sair e testar
exit
make remote-exec CMD="terraform version"
```

### Workspace Vazio

**Sintomas**: Conectar ao EC2 e `~/workspace/` está vazio

**Causa**: Sincronização não executada

**Solução**:
```bash
# Sincronizar
make sync

# Verificar
make remote-exec CMD="ls -la ~/workspace/"
```

### Sem Espaço em Disco

**Sintomas**:
```
No space left on device
```

**Soluções**:

```bash
# 1. Conectar ao EC2
make remote-shell

# 2. Verificar uso de disco
df -h

# 3. Limpar .terraform/
cd ~/workspace
rm -rf .terraform/

# 4. Limpar cache de providers
rm -rf ~/.terraform.d/plugin-cache/

# 5. Se necessário, aumentar volume
# Editar infrastructure/ec2.tf
# root_block_device { volume_size = 50 }
# terraform apply
```

## Problemas de Configuração

### MODULE_PATH Incorreto

**Sintomas**:
```
Erro: Módulo não encontrado em /path/to/module
```

**Solução**:
```bash
# Verificar path atual
cat config.env | grep MODULE_PATH

# Verificar se diretório existe
ls -la /path/to/seu/modulo

# Corrigir config.env
vim config.env
# MODULE_PATH=/caminho/correto/para/modulo

# Testar
make sync
```

### IP Mudou ao Reiniciar EC2

**Sintomas**: Conexão SSH falha após reiniciar EC2

**Causa**: IP público muda ao parar/iniciar EC2 (comportamento normal da AWS)

**Solução**: Atualizar known_hosts com o novo IP

```bash
# Verificar IP atual
make status

# Atualizar known_hosts
ssh-keygen -R $(cd infrastructure && terraform output -raw ec2_ip)

# Testar conexão
make remote-shell
```

## Problemas de Performance

### Testes Muito Lentos

**Causas**:
1. Instância EC2 pequena
2. Módulo muito complexo
3. Muitos providers

**Soluções**:

```bash
# 1. Usar instância maior
vim infrastructure/terraform.tfvars
# instance_type = "t3.large"

# 2. Aplicar mudança
cd infrastructure
terraform apply

# 3. Aguardar reinicialização
make status
```

### Sincronização Lenta

**Soluções**:
- Adicionar mais exclusões no Makefile
- Usar rsync com compressão (já habilitado)
- Verificar conexão de internet

## Problemas de Custos

### Conta AWS Alta

**Causas**:
1. EC2 rodando 24/7
2. Transferência de dados excessiva

**Soluções**:

```bash
# 1. Parar EC2 quando não usar
make stop

# 2. Destruir quando não precisar mais
make destroy

# 3. Verificar custos no AWS Cost Explorer

# 4. Usar instância menor
# t3.small em vez de t3.medium
```

## Obtendo Ajuda

### Logs Úteis

```bash
# Log do user-data (EC2)
make remote-exec CMD="sudo cat /var/log/user-data.log"

# Status do Terraform
cd infrastructure
terraform show

# Outputs do Terraform
cd infrastructure
terraform output

# Status da instância
aws ec2 describe-instances --instance-ids $(cd infrastructure && terraform output -raw ec2_id)
```

### Informações para Reportar Issues

Ao reportar problemas, inclua:

1. Comando executado
2. Erro completo
3. Saída de `make status`
4. Sistema operacional
5. Versões:
```bash
terraform version
aws --version
fswatch --version
rsync --version
```

### Onde Obter Ajuda

- Issues do GitHub: [link]
- Documentação: [docs/](.)
- AWS Support (para problemas AWS)

## Reset Completo

Se nada funcionar, reset completo:

```bash
# 1. Destruir infraestrutura
make destroy

# 2. Limpar configurações locais
rm -f config.env
rm -rf infrastructure/.terraform/
rm -f infrastructure/terraform.tfstate*
rm -f infrastructure/.terraform.lock.hcl

# 3. Reconfigurar
make setup

# 4. Editar configurações
vim config.env
vim infrastructure/terraform.tfvars

# 5. Provisionar novamente
make provision
```

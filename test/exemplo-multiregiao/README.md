# CL037 - VPC Configuration

Este é um exemplo de implementação de configuração de VPCs para conta de um cliente da OpsTeam. O cliente é identificado pelo código **CL037**.

## Estrutura do Projeto

```
test/CL037-SEC/
├── README.md
├── collect_vpc_data.sh          # Script de coleta de dados de VPCs
├── client-reports/              # Relatórios gerados (não versionado)
├── sa-east-1/                   # Configurações para região São Paulo
└── us-east-1/                   # Configurações para região Norte da Virgínia
```

## Script de Coleta de Dados

O script `collect_vpc_data.sh` automatiza a coleta de informações de VPCs existentes em todas as contas do cliente CL037.

### Funcionalidade

- Busca automaticamente todos os profiles AWS com prefixo `CL037-`
- Consulta VPCs nas regiões configuradas (us-east-1 e sa-east-1)
- Gera relatório CSV com:
  - Profile AWS
  - Região
  - VPC ID
  - Nome da VPC
  - CIDR IPv4
  - Status de VPC default

### Uso

```bash
./collect_vpc_data.sh
```

O relatório é salvo em `client-reports/vpc_inventory.csv`.

### Objetivo

Este levantamento ajuda a identificar CIDRs já utilizados nas contas do cliente, evitando conflitos de endereçamento IP ao criar novas VPCs.

## Análise de Endereçamento IP

Após análise dos CIDRs existentes nas contas do cliente, foram identificados os seguintes blocos em uso:

**Blocos 10.x.x.x:**
- 10.30.0.0/16, 10.71.0.0/16, 10.72.0.0/16, 10.73.0.0/16, 10.74.0.0/20
- 10.81.0.0/16, 10.83.0.0/16, 10.247.0.0/16, 10.254.0.0/16

**Blocos 172.x.x.x:**
- 172.17.0.0/20, 172.17.16.0/20, 172.18.0.0/16, 172.20.0.0/22
- 172.31.0.0/16 (VPCs default), 172.150.0.0/16

### Decisão de Endereçamento

Para evitar conflitos e garantir escalabilidade, foram selecionados os seguintes blocos CIDR:

| Região | VPC CIDR | Subnets Públicas | Subnets Privadas |
|--------|----------|------------------|------------------|
| **us-east-1** | 10.100.0.0/16 | 10.100.0.0/20<br>10.100.16.0/20<br>10.100.32.0/20 | 10.100.128.0/20<br>10.100.144.0/20<br>10.100.160.0/20 |
| **sa-east-1** | 10.101.0.0/16 | 10.101.0.0/20<br>10.101.16.0/20<br>10.101.32.0/20 | 10.101.128.0/20<br>10.101.144.0/20<br>10.101.160.0/20 |

**Justificativa:**
- Blocos 10.100.0.0/16 e 10.101.0.0/16 não estão em uso em nenhuma conta
- Não há sobreposição entre as regiões
- Cada subnet /20 fornece 4.096 IPs, suficiente para o caso de uso
- Subnets públicas no início do bloco (0-63) e privadas no meio (128-191)

## Configurações por Região

### sa-east-1 (São Paulo)

**Estrutura:**
```
test/CL037-SEC/sa-east-1/
├── config.tf    # Backend S3 e provider AWS
└── main.tf      # Configuração da VPC
```

**Recursos criados:**
- VPC: 10.101.0.0/16
- 3 Subnets Públicas (sae1-az1, sae1-az2, sae1-az3)
- 3 Subnets Privadas (sae1-az1, sae1-az2, sae1-az3)
- Internet Gateway
- Route Tables (6 customizadas + 1 main)
- Network ACLs
- Security Groups

**Deploy:**
```bash
cd test/CL037-SEC/sa-east-1
terraform init
terraform plan
terraform apply
```

### us-east-1 (Norte da Virgínia)

**Estrutura:**
```
test/CL037-SEC/us-east-1/
├── config.tf    # Backend S3 e provider AWS
└── main.tf      # Configuração da VPC
```

**Recursos criados:**
- VPC: 10.100.0.0/16
- 3 Subnets Públicas (use1-az1, use1-az2, use1-az3)
- 3 Subnets Privadas (use1-az1, use1-az2, use1-az3)
- Internet Gateway
- Route Tables (6 customizadas + 1 main)
- Network ACLs
- Security Groups

**Deploy:**
```bash
cd test/CL037-SEC/us-east-1
terraform init
terraform plan
terraform apply
```

## Como Reproduzir

### Pré-requisitos

1. **AWS CLI configurado** com profiles do cliente CL037
2. **Terraform** instalado (versão >= 1.0)
3. **Bucket S3** para tfstate: `roadcard-security-terraform-state`
4. **Permissões AWS** para criar recursos de rede

### Configuração de Profiles AWS

No arquivo `~/.aws/config`, configure os profiles:
```ini
[profile CL037]
# Profile base para acesso à conta da consultoria

[profile CL037-SEC]
# Profile para conta de segurança do cliente
```

### Passo a Passo

#### 1. Coletar Dados de CIDRs Existentes

Execute o script de coleta para identificar CIDRs já utilizados:

```bash
cd test/CL037-SEC
./collect_vpc_data.sh
```

O relatório será salvo em `client-reports/vpc_inventory.csv`.

#### 2. Criar Bucket S3 para Terraform State

```bash
aws s3api create-bucket \
  --bucket roadcard-security-terraform-state \
  --region us-east-1 \
  --profile CL037-SEC

aws s3api put-bucket-versioning \
  --bucket roadcard-security-terraform-state \
  --versioning-configuration Status=Enabled \
  --profile CL037-SEC

aws s3api put-bucket-encryption \
  --bucket roadcard-security-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' \
  --profile CL037-SEC

aws s3api put-public-access-block \
  --bucket roadcard-security-terraform-state \
  --public-access-block-configuration "BlockPublicAcls=true,BlockPublicPolicy=true,IgnorePublicAcls=true,RestrictPublicBuckets=true" \
  --profile CL037-SEC
```

#### 3. Deletar VPCs Default (Opcional)

Se desejar remover as VPCs default das regiões:

```bash
# us-east-1
aws ec2 delete-vpc --vpc-id <vpc-id> --region us-east-1 --profile CL037-SEC

# sa-east-1
aws ec2 delete-vpc --vpc-id <vpc-id> --region sa-east-1 --profile CL037-SEC
```

#### 4. Deploy da VPC em us-east-1

```bash
cd test/CL037-SEC/us-east-1
terraform init
terraform plan
terraform apply
```

#### 5. Deploy da VPC em sa-east-1

```bash
cd test/CL037-SEC/sa-east-1
terraform init
terraform plan
terraform apply
```

### Validação

Após o deploy, valide os recursos criados:

```bash
# Listar VPCs
aws ec2 describe-vpcs --region us-east-1 --profile CL037-SEC
aws ec2 describe-vpcs --region sa-east-1 --profile CL037-SEC

# Listar Subnets
aws ec2 describe-subnets --region us-east-1 --profile CL037-SEC
aws ec2 describe-subnets --region sa-east-1 --profile CL037-SEC

# Listar Internet Gateways
aws ec2 describe-internet-gateways --region us-east-1 --profile CL037-SEC
aws ec2 describe-internet-gateways --region sa-east-1 --profile CL037-SEC
```

## Arquitetura de Rede

### Características

- **Sem NAT Gateway/Instance**: Configurado para acesso via VPN Client
- **Subnets Públicas**: Com auto-assign de IP público e rota para IGW
- **Subnets Privadas**: Sem acesso direto à internet
- **Multi-AZ**: 3 zonas de disponibilidade por região
- **DNS**: Habilitado (hostnames e support)

### Caso de Uso

Esta VPC foi projetada para hospedar:
- **OpenSearch** (SIEM) em subnets privadas
- Acesso via **AWS VPN Client**
- Sem necessidade de saída para internet das subnets privadas

## Manutenção

### Atualizar Infraestrutura

```bash
cd test/CL037-SEC/<região>
terraform plan
terraform apply
```

### Destruir Infraestrutura

```bash
cd test/CL037-SEC/<região>
terraform destroy
```

### Visualizar Estado Atual

```bash
cd test/CL037-SEC/<região>
terraform show
```

## Troubleshooting

### Erro: VPC default ainda existe

Se houver erro ao criar recursos devido à VPC default, delete-a manualmente:
```bash
aws ec2 delete-vpc --vpc-id <vpc-id> --region <região> --profile CL037-SEC
```

### Erro: Bucket S3 não encontrado

Verifique se o bucket foi criado e se o profile tem permissões:
```bash
aws s3 ls s3://roadcard-security-terraform-state --profile CL037-SEC
```

### Erro: Credenciais AWS

Verifique se os profiles estão configurados corretamente:
```bash
aws sts get-caller-identity --profile CL037-SEC
```

## Atualizações

Este é um exemplo básico de implementação do módulo. A versão completa e atualizada deste projeto está disponível no repositório oficial do cliente:

- **GitLab**: https://gitlab.dev.roadcard.com.br/infra/terraform-aws-vpc

Novas funcionalidades e melhorias são publicadas no repositório oficial.

## Backend Terraform

O estado do Terraform é armazenado no bucket S3:
- **Bucket**: `roadcard-terraform-state-us-east-1`
- **Região**: us-east-1
- **Conta**: CL037-SEC

---

*Documentação em desenvolvimento*

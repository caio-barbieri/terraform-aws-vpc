# Terraform AWS VPC - Módulo de Configuração de Redes

Este é um módulo Terraform flexível e reutilizável para criar e gerenciar VPCs na AWS. O módulo suporta diversos componentes de rede como subnets públicas/privadas, Internet Gateways, NAT Gateways, NAT Instances, VPC Peering, Transit Gateway, VPC Endpoints e muito mais.

## 📋 Índice

- [Como Funciona](#como-funciona)
- [Exemplo Prático](#exemplo-prático)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Componentes Suportados](#componentes-suportados)
- [Uso Básico](#uso-básico)
- [NAT Instance - Problema e Solução](#nat-instance---problema-e-solução)
- [Boas Práticas de Segurança](#boas-práticas-de-segurança)
- [Exemplos Adicionais](#exemplos-adicionais)

## Como Funciona

Este módulo utiliza uma abordagem **declarativa** onde você define toda a configuração da VPC através de uma única variável complexa chamada `vpc_config`. O módulo então processa essa configuração e cria todos os recursos necessários na AWS.

### Conceito Principal

```
Você define → vpc_config (mapa de configuração)
                    ↓
Módulo processa → Cria recursos na AWS
                    ↓
Resultado → VPC completa com todos os componentes
```

### Fluxo de Trabalho

1. **Definição**: Você cria um arquivo `main.tf` que chama o módulo
2. **Configuração**: Define a variável `vpc_config` com as especificações desejadas
3. **Processamento**: O módulo interpreta a configuração e determina quais recursos criar
4. **Criação**: Terraform provisiona os recursos na AWS
5. **Estado**: O estado é armazenado (local ou remoto, como S3)

## Exemplo Prático

Para ilustrar como o módulo funciona, vamos usar um exemplo real de implementação multi-região para uma conta de segurança.

> **Nota**: Este exemplo é uma implementação básica do projeto que foi desenvolvido para um cliente real. A versão completa e atualizada deste projeto está disponível no repositório oficial do cliente em: https://gitlab.dev.roadcard.com.br/infra/terraform-aws-vpc

### Cenário: VPC Multi-Região para Segurança

**Objetivo**: Criar VPCs em duas regiões AWS (us-east-1 e sa-east-1) para hospedar um SIEM baseado em OpenSearch, com acesso via VPN Client.

**Estrutura do Exemplo**:
```
test/exemplo-multiregiao/
├── README.md                    # Documentação específica do exemplo
├── collect_vpc_data.sh          # Script para coletar CIDRs existentes
├── client-reports/              # Relatórios gerados (não versionado)
├── us-east-1/
│   ├── config.tf               # Backend S3 e provider
│   └── main.tf                 # Configuração da VPC
└── sa-east-1/
    ├── config.tf               # Backend S3 e provider
    └── main.tf                 # Configuração da VPC
```

### Passo 1: Planejamento de Endereçamento

Antes de criar as VPCs, é importante identificar CIDRs já utilizados para evitar conflitos. O script `collect_vpc_data.sh` automatiza essa coleta:

```bash
cd test/exemplo-multiregiao
./collect_vpc_data.sh
```

Este script:
- Busca todos os profiles AWS com um prefixo específico
- Lista todas as VPCs existentes em cada conta
- Gera um CSV com VPC ID, Nome, CIDR, Região e se é VPC default
- Salva em `client-reports/vpc_inventory.csv`

**Resultado da análise**:
- Blocos 10.x já utilizados: 10.30.0.0/16, 10.71-73.0.0/16, 10.81.0.0/16, etc.
- Blocos 172.x já utilizados: 172.17.0.0/20, 172.18.0.0/16, 172.31.0.0/16, etc.
- **Blocos disponíveis identificados**: 10.100.0.0/16 e 10.101.0.0/16

### Passo 2: Configuração do Backend

Arquivo `us-east-1/config.tf`:
```hcl
terraform {
  backend "s3" {
    bucket = "empresa-terraform-state"
    key    = "infrastructure/us-east-1/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "meu-profile"
}
```

### Passo 3: Definição da VPC

Arquivo `us-east-1/main.tf`:
```hcl
module "vpc" {
  source = "../../.."  # Aponta para a raiz do módulo

  vpc_config = {
    # Configuração da VPC principal
    vpc = {
      cidr_block = "10.100.0.0/16"
    }
    
    # Tags globais aplicadas a todos os recursos
    global = {
      tags = {
        Name        = "security-vpc"
        Environment = "security"
        ManagedBy   = "Terraform"
        Project     = "SIEM"
      }
    }
    
    # NAT Gateway desabilitado (não necessário para este caso)
    nat_gateway = {
      create = false
    }
    
    # NAT Instance desabilitado
    nat_instance = {
      create = false
    }
    
    # Definição das camadas de subnets
    subnet_layers = [
      {
        name        = "public"
        cidr_block  = ["10.100.0.0/20", "10.100.16.0/20", "10.100.32.0/20"]
        scope       = "public"
        map_public_ip_on_launch = true
        has_outbound_internet_access_via_natgw = false
        has_outbound_internet_access_via_natinstance = false
      },
      {
        name        = "private"
        cidr_block  = ["10.100.128.0/20", "10.100.144.0/20", "10.100.160.0/20"]
        scope       = "private"
        has_outbound_internet_access_via_natgw = false
        has_outbound_internet_access_via_natinstance = false
      }
    ]
  }
}
```

### Passo 4: Entendendo a Configuração

**VPC Principal** (`vpc`):
- Define o CIDR principal da VPC
- Habilita DNS por padrão
- Cria a VPC base onde todos os outros recursos serão criados

**Tags Globais** (`global.tags`):
- Aplicadas automaticamente a todos os recursos criados
- Facilita identificação e billing
- Permite filtros e buscas na AWS

**Subnet Layers** (`subnet_layers`):
- **Conceito**: Agrupa subnets com características similares
- **Public Layer**: 
  - 3 subnets em 3 AZs diferentes
  - Auto-assign de IP público habilitado
  - Rota para Internet Gateway criada automaticamente
- **Private Layer**:
  - 3 subnets em 3 AZs diferentes
  - Sem IP público
  - Sem rota para internet (ideal para OpenSearch)

**O que o módulo cria automaticamente**:
1. VPC com o CIDR especificado
2. Internet Gateway (porque há subnets públicas)
3. 6 Subnets (3 públicas + 3 privadas)
4. 6 Route Tables customizadas (uma por subnet)
5. 1 Route Table principal (main)
6. Rotas para IGW nas route tables públicas
7. 2 Network ACLs (uma por layer)
8. Associações de subnets com NACLs
9. Security Group padrão (allowlist)
10. Security Group default (denylist)
11. DHCP Options Set
12. Managed Prefix List para internet

### Passo 5: Deploy

```bash
cd test/exemplo-multiregiao/us-east-1
terraform init
terraform plan    # Revise os recursos que serão criados
terraform apply   # Confirme e crie os recursos
```

**Saída esperada**: 38 recursos criados

### Passo 6: Replicação para Outra Região

Para sa-east-1, basta:
1. Copiar a estrutura de arquivos
2. Ajustar o CIDR para 10.101.0.0/16
3. Mudar a região no provider para sa-east-1
4. Ajustar a key do backend S3

O módulo cria exatamente a mesma estrutura, mas em outra região.

## Estrutura do Projeto

```
terraform-aws-vpc/
├── README.md                    # Este arquivo
├── variables.tf                 # Definição da variável vpc_config
├── main.tf                      # Lógica principal
├── aws_vpc.tf                   # Recursos de VPC
├── aws_subnet.tf                # Recursos de Subnets
├── aws_igw.tf                   # Internet Gateway
├── aws_nat_gateway.tf           # NAT Gateway
├── aws_nat_instance.tf          # NAT Instance
├── aws_peering.tf               # VPC Peering
├── aws_transit_gateway.tf       # Transit Gateway
├── aws_vpc_endpoint.tf          # VPC Endpoints
├── import_natinstance_ami.sh    # Script para importar AMI NAT
└── test/                        # Exemplos de uso
    ├── exemplo-multiregiao/     # Exemplo multi-região
    ├── simple_vpc/              # VPC simples
    ├── security_group/          # Com security groups
    └── transit_gateway/         # Com transit gateway
```

## Componentes Suportados

O módulo suporta a criação e configuração dos seguintes componentes:

| Componente | Descrição | Configuração |
|------------|-----------|--------------|
| **VPC** | Rede virtual principal | `vpc_config.vpc` |
| **Subnets** | Subnets públicas e privadas em múltiplas AZs | `vpc_config.subnet_layers` |
| **Internet Gateway** | Acesso à internet para subnets públicas | `vpc_config.igw` |
| **NAT Gateway** | Saída para internet de subnets privadas | `vpc_config.nat_gateway` |
| **NAT Instance** | Alternativa econômica ao NAT Gateway | `vpc_config.nat_instance` |
| **Route Tables** | Tabelas de roteamento customizadas | Criadas automaticamente |
| **Network ACLs** | Firewall em nível de subnet | `vpc_config.subnet_layers[].network_acl_rules` |
| **Security Groups** | Firewall em nível de instância | `vpc_config.security_groups` |
| **VPC Peering** | Conexão entre VPCs | `vpc_config.peering_connection` |
| **Transit Gateway** | Hub central para múltiplas VPCs | `vpc_config.transit_gateway` |
| **VPC Endpoints** | Acesso privado a serviços AWS | `vpc_config.vpc_endpoints` |
| **DHCP Options** | Configurações DHCP customizadas | `vpc_config.dhcp_options` |

## Uso Básico

### 1. Estrutura Mínima

```hcl
module "vpc" {
  source = "caminho/para/modulo"

  vpc_config = {
    vpc = {
      cidr_block = "10.0.0.0/16"
    }
    subnet_layers = [
      {
        name       = "public"
        cidr_block = ["10.0.1.0/24"]
        scope      = "public"
      }
    ]
  }
}
```

### 2. Com NAT Gateway

```hcl
module "vpc" {
  source = "caminho/para/modulo"

  vpc_config = {
    vpc = {
      cidr_block = "10.0.0.0/16"
    }
    nat_gateway = {
      create = true
      az_widerange = 2  # NAT em 2 AZs
    }
    subnet_layers = [
      {
        name       = "public"
        cidr_block = ["10.0.1.0/24", "10.0.2.0/24"]
        scope      = "public"
      },
      {
        name       = "private"
        cidr_block = ["10.0.10.0/24", "10.0.20.0/24"]
        scope      = "private"
        has_outbound_internet_access_via_natgw = true
      }
    ]
  }
}
```

### 3. Com VPC Endpoints

```hcl
module "vpc" {
  source = "caminho/para/modulo"

  vpc_config = {
    vpc = {
      cidr_block = "10.0.0.0/16"
    }
    vpc_endpoints = {
      s3 = {
        service_type = "Gateway"
      }
      ec2 = {
        service_type        = "Interface"
        private_dns_enabled = true
      }
    }
    subnet_layers = [
      {
        name       = "private"
        cidr_block = ["10.0.1.0/24"]
        scope      = "private"
      }
    ]
  }
}
```

## NAT Instance - Problema e Solução

### ⚠️ Problema Identificado

No final de 2024, foi observado que o projeto parou de funcionar porque a **AMI da NAT Instance foi removida de todas as regiões AWS, exceto Irlanda (eu-west-1)**.

### ✅ Solução

Um script chamado `import_natinstance_ami.sh` foi criado para automatizar a importação da AMI para outras regiões.

**Como usar**:

```bash
# Tornar o script executável
chmod +x import_natinstance_ami.sh

# Executar o script
./import_natinstance_ami.sh
```

O script irá:
1. Copiar a AMI da região eu-west-1
2. Importar para a região desejada
3. Retornar o ID da nova AMI

**Uso no Terraform**:

```hcl
nat_instance = {
  create    = true
  ami_id    = "ami-xxxxxxxxx"  # ID retornado pelo script
  az_widerange = 2
}
```

### Alternativa: NAT Gateway

Se você não precisa de NAT Instance especificamente, considere usar NAT Gateway:

**Vantagens do NAT Gateway**:
- Gerenciado pela AWS
- Alta disponibilidade automática
- Melhor performance
- Sem necessidade de gerenciar AMIs

**Desvantagens**:
- Custo mais alto que NAT Instance
- Cobrado por hora + tráfego

## Boas Práticas de Segurança

### 1. Não Exponha Dados Sensíveis

❌ **Evite**:
```hcl
variable "db_password" {
  default = "senha123"  # NUNCA faça isso!
}
```

✅ **Faça**:
```hcl
variable "db_password" {
  type      = string
  sensitive = true
  # Valor passado via variável de ambiente TF_VAR_db_password
}
```

### 2. Use Backend Remoto com Criptografia

```hcl
terraform {
  backend "s3" {
    bucket         = "meu-tfstate"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # Para lock de estado
  }
}
```

### 3. Use Roles IAM ao Invés de Access Keys

```hcl
provider "aws" {
  region = "us-east-1"
  # Usa role do EC2/ECS/Lambda automaticamente
  # Ou profile configurado em ~/.aws/config
  profile = "meu-profile"
}
```

### 4. Versionamento do Bucket de State

```bash
aws s3api put-bucket-versioning \
  --bucket meu-tfstate \
  --versioning-configuration Status=Enabled
```

### 5. Use .gitignore

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
.terraform.lock.hcl

# Dados sensíveis
secrets/
*.pem
*.key
```

## Exemplos Adicionais

O diretório `test/` contém diversos exemplos práticos:

### simple_vpc
VPC básica com subnets públicas e privadas.

```bash
cd test/simple_vpc
terraform init
terraform apply
```

### security_group
Exemplo de VPC com security groups customizados.

```bash
cd test/security_group
terraform init
terraform apply
```

### transit_gateway
VPC conectada a um Transit Gateway para arquitetura hub-and-spoke.

```bash
cd test/transit_gateway
terraform init
terraform apply
```

### vpc_default_configs
Demonstra o uso de configurações padrão do módulo.

```bash
cd test/vpc_default_configs
terraform init
terraform apply
```

## Variáveis Principais

### vpc_config

Variável complexa que contém toda a configuração da VPC. Estrutura:

```hcl
vpc_config = {
  vpc              = { ... }  # Configuração da VPC
  global           = { ... }  # Tags e configurações globais
  igw              = { ... }  # Internet Gateway
  nat_gateway      = { ... }  # NAT Gateway
  nat_instance     = { ... }  # NAT Instance
  subnet_layers    = [ ... ]  # Subnets
  security_groups  = [ ... ]  # Security Groups
  vpc_endpoints    = { ... }  # VPC Endpoints
  peering_connection = [ ... ] # VPC Peering
  transit_gateway  = { ... }  # Transit Gateway
  dhcp_options     = { ... }  # DHCP Options
}
```

Para detalhes completos de cada subitem, consulte o arquivo `variables.tf`.

## Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

## Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.

## Referências

- HashiCorp (2023) Resource: aws_vpc. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
- HashiCorp (2023) Resource: aws_subnet. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
- HashiCorp (2023) Resource: aws_internet_gateway. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
- HashiCorp (2023) Resource: aws_nat_gateway. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
- HashiCorp (2023) Resource: aws_vpc_peering_connection. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection
- HashiCorp (2023) Resource: aws_vpc_endpoint. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint

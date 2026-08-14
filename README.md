# Terraform AWS VPC

Módulo Terraform reutilizável para criar uma VPC AWS com subnets distribuídas por zona de disponibilidade, tabelas de rotas, NACLs, Internet Gateway, NAT Gateway ou NAT Instance, Security Groups, VPC Endpoints, VPC Peering e Transit Gateway.

## Requisitos

- Terraform `>= 1.3.1`
- AWS provider `>= 6.0.0`
- Credenciais e região configuradas pelo módulo raiz

Os testes mockados exigem Terraform `>= 1.7`; CI usa Terraform `1.15.8`. Essa exigência de desenvolvimento não altera o requisito de runtime do módulo.

O módulo não configura provider nem backend. O módulo raiz consumidor continua responsável por autenticação, região, estado remoto e lock.

## Uso rápido

```hcl
provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "git::https://github.com/opsteamhub/terraform-aws-vpc.git?ref=main"

  vpc_config = {
    vpc = {
      cidr_block = "10.0.0.0/16"
    }

    global = {
      tags = {
        Name        = "myapp"
        Environment = "production"
        Project     = "myapp"
        Owner       = "platform"
      }
    }

    subnet_layers = [
      {
        name         = "public"
        scope        = "public"
        az_widerange = 2
      },
      {
        name         = "private"
        az_widerange = 2
      }
    ]
  }
}
```

Quando `cidr_block` não é informado na camada, o módulo deriva subnets determinísticas e não sobrepostas na ordem declarada. O padrão adiciona 8 bits ao prefixo da VPC (`/16` vira `/24`); use `netlength`, `netnum` ou CIDRs explícitos quando precisar controlar o layout.

Em produção, substitua `ref=main` por uma tag ou SHA revisada. O repositório ainda não possui releases versionadas.

Exemplos locais executáveis estão em [`examples/basic`](examples/basic) e [`examples/complete`](examples/complete).

## Documentação

- [Referência completa de `vpc_config`](docs/CONFIGURATION.md)
- [Arquitetura e limites de responsabilidade](docs/ARCHITECTURE.md)
- [Migração para v2](docs/MIGRATION-v2.md)
- [Como contribuir](CONTRIBUTING.md)
- [Política de segurança](SECURITY.md)
- [Changelog](CHANGELOG.md)

## O que é criado por padrão

Para uma VPC nova, o módulo cria:

- VPC com DNS habilitado;
- Internet Gateway;
- DHCP Options com domínio regional correto;
- subnets, uma route table e uma NACL por camada;
- rota para Internet Gateway nas subnets com `scope = "public"`;
- default NACL bloqueada e default Security Group sem regras;
- Security Group auxiliar limitado ao CIDR da VPC;
- managed prefix list para `0.0.0.0/0`.

NAT, IPv6, Flow Logs, endpoints, peering e Transit Gateway são opt-in.

## Modelo de segurança de rede

Os Security Groups são o filtro primário e stateful. Para preservar conectividade genérica, as NACLs de cada camada são neutras por padrão e permitem todo o tráfego IPv4; quando IPv6 está habilitado, também permitem IPv6. Use `network_acl_rules` e Security Groups específicos para impor restrições compatíveis com o workload. A opção legada de quarentena mantém o bloqueio total da default NACL para subnets selecionadas.

Flow Logs são opt-in para evitar criar custo e destinos de logs sem decisão do consumidor. Para ambientes governados, habilite-os no baseline conforme o exemplo completo.

## NAT Gateway

Uma subnet pública já é candidata a hospedar o NAT Gateway; não é necessário repetir `nat_gw_scope = "public"`.

```hcl
nat_gateway = {
  create       = true
  az_widerange = 2
}

subnet_layers = [
  {
    name         = "public"
    scope        = "public"
    az_widerange = 2
    cidr_block   = ["10.0.0.0/24", "10.0.1.0/24"]
  },
  {
    name                                   = "private"
    az_widerange                           = 2
    cidr_block                             = ["10.0.10.0/24", "10.0.11.0/24"]
    has_outbound_internet_access_via_natgw = true
  }
]
```

Revise o custo antes do apply: o módulo pode criar mais de um NAT Gateway conforme `az_widerange`.

## NAT Instance

A AWS não mantém mais uma NAT AMI atual. Use uma AMI própria baseada em um sistema operacional suportado ou prefira NAT Gateway. A NAT AMI precisa habilitar IP forwarding e NAT de forma persistente.

```hcl
nat_instance = {
  create                    = true
  ami_id                    = "ami-0123456789abcdef0"
  az_widerange              = 1
  instance_type             = "t3.medium"
  iam_instance_profile_name = "nat-instance-ssm"
  instance_tags = {
    PatchGroup = "network"
  }
}
```

O launch template exige IMDSv2. O Security Group da NAT Instance aceita entrada somente do CIDR da VPC; a saída permanece aberta porque esse é o objetivo do recurso.

Quando há NAT Instances em múltiplas AZs, cada subnet privada prefere a ENI NAT da mesma AZ. Cada instância é mantida por um Auto Scaling Group com health check EC2. Isso fornece isolamento e recuperação por AZ, mas não altera automaticamente rotas para outra AZ durante uma falha regional da NAT Instance.

## VPC Flow Logs

O caminho mais simples cria Log Group, role de entrega e Flow Log para todo o tráfego da VPC:

```hcl
flow_logs = {
  create                       = true
  traffic_type                 = "ALL"
  cloudwatch_retention_in_days = 90
  cloudwatch_kms_key_id        = "arn:aws:kms:us-east-1:123456789012:key/..."
}
```

A trust policy gerada restringe o serviço pelo account ID e ARN do Flow Log. Para uma centralização já existente, informe `log_destination_arn` e `iam_role_arn`. Destinos `s3` e `kinesis-data-firehose` exigem `log_destination_arn` e suas policies devem ser mantidas pelo consumidor.

## IPv6 dual-stack

```hcl
ipv6 = {
  enabled = true
}
```

Para uma VPC nova, o padrão solicita um bloco IPv6 `/56` da AWS. Cada subnet habilitada recebe um `/64` determinístico e não sobreposto. Subnets públicas recebem rota `::/0` pelo Internet Gateway; subnets privadas usam um Egress-only Internet Gateway.

Para uma VPC existente, informe o CIDR já associado e decida explicitamente se o módulo deve criar o Egress-only Internet Gateway:

```hcl
ipv6 = {
  enabled                             = true
  assign_generated_ipv6_cidr_block    = false
  ipv6_cidr_block                     = "2600:1f18:abcd:1200::/56"
  create_egress_only_internet_gateway = false
  egress_only_internet_gateway_id     = "eigw-0123456789abcdef0"
}
```

## VPC Endpoints

Gateway endpoints usam todas as route tables criadas pelo módulo quando `route_table_ids` e `route_tables_filter` não são informados.

```hcl
vpc_endpoints = {
  s3 = {
    service_type = "Gateway"
  }

  ec2 = {
    service_type = "Interface"
    subnet_ids    = ["subnet-0123456789abcdef0"]
  }
}
```

Para Interface endpoints, informe `subnet_ids` para seleção determinística. Sem IDs explícitos, o filtro legado procura `tag:subnet_layer = awssvc`; use `subnet_filter` para selecionar outra camada.

## Transit Gateway

O módulo pode criar ou referenciar um Transit Gateway, anexar a VPC e gerenciar rotas dos dois lados:

```hcl
transit_gateway = {
  core = {
    create = true

    vpc_attachment = {
      create             = true
      subnet_layer_names = ["private"]
      ipv6_support       = "enable"
    }

    transit_gateway_routes = {
      local_vpc = {
        destination_cidr_block = "10.0.0.0/16"
      }
    }

    vpc_routes = {
      shared_services = {
        destination_cidr_block = "10.100.0.0/16"
        subnet_layer_names     = ["private"]
      }
    }
  }
}
```

Para um Transit Gateway existente, configure `create = false`, `transit_gateway_id` e o `transit_gateway_route_table_id` de cada rota TGW. O módulo não tenta descobrir route tables de um gateway compartilhado.

## VPC existente

```hcl
vpc_config = {
  vpc = {
    create = false
    vpc_id = "vpc-0123456789abcdef0"
  }
}
```

`vpc_id` é obrigatório quando `create = false`. Os componentes que suportam VPC existente usam esse ID; recursos padrão pertencentes a uma VPC nova não são alterados.
O módulo consulta a VPC existente para obter o CIDR usado pelos Security Groups gerados para NAT Instance e Interface Endpoints.

## Contrato principal

Todo o contrato entra em `vpc_config`:

| Campo | Finalidade | Padrão |
|---|---|---|
| `vpc` | VPC nova por CIDR/IPAM ou referência a VPC existente | obrigatório |
| `ipam` | Alias legado para `vpc.ipv4_ipam_pool_id` | `null` |
| `global.tags` | Tags compartilhadas | `{}` |
| `global.az` | Estado e Zone IDs excluídos | `{}` |
| `flow_logs` | Entrega para CloudWatch Logs, S3 ou Firehose | desabilitado |
| `ipv6` | Bloco IPv6, subnets dual-stack e egress-only IGW | desabilitado |
| `subnet_layers` | Camadas, CIDRs, AZs, rotas e NACLs | `[]` |
| `igw` | Internet Gateway | `{ create = true }` |
| `dhcp_options` | DHCP Options | DNS da Amazon e domínio regional |
| `nat_gateway` | NAT Gateways e AZs | desabilitado |
| `nat_instance` | NAT Instances e AMI própria | desabilitado |
| `security_groups` | Security Groups e regras | `[]` |
| `vpc_endpoints` | Gateway e Interface endpoints | `{}` |
| `peering_connection` | Request/accept e rotas de peering | `[]` |
| `transit_gateway` | Gateways, VPC attachments e rotas TGW/VPC | `{}` |

O Terraform valida combinações essenciais antes do plan, incluindo CIDR versus IPAM, VPC existente sem ID, NAT sem subnet pública, listas de CIDR menores que a quantidade de AZs, nomes duplicados de subnet layer, tipos de endpoint e contratos de peering/TGW.

## Outputs

| Output | Conteúdo |
|---|---|
| `vpc_id` | ID da VPC criada ou referenciada |
| `vpc_ids` | IDs de VPCs criadas, mantido por compatibilidade |
| `subnet_ids` | IDs por layer/AZ |
| `public_subnet_ids` | IDs de subnets públicas |
| `private_subnet_ids` | IDs de subnets privadas |
| `route_table_ids` | IDs de route tables por subnet |
| `internet_gateway_id` | ID do Internet Gateway criado ou informado |
| `ipv6_cidr_block` | CIDR IPv6 associado à VPC |
| `egress_only_internet_gateway_id` | ID do Egress-only Internet Gateway |
| `nat_gateway_ids` | IDs de NAT Gateways por subnet pública |
| `nat_instance_network_interface_ids` | ENIs das NAT Instances por subnet pública |
| `sg_ids` | IDs dos Security Groups configurados |
| `vpc_endpoint_ids` | IDs dos endpoints pelo nome configurado |
| `transit_gateway_ids` | IDs de Transit Gateways criados ou referenciados |
| `transit_gateway_vpc_attachment_ids` | IDs dos attachments por Transit Gateway |
| `vpc_flow_log_id` | ID do VPC Flow Log |
| `vpc_flow_log_group_arn` | ARN do Log Group gerenciado ou informado |
| `peering_connection_data` | Dados das conexões de peering criadas |

## Verificação local

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test -test-directory=testing

tflint --init
tflint --recursive --format compact
trivy config --severity HIGH,CRITICAL --exit-code 1 .

terraform -chdir=examples/basic init -backend=false
terraform -chdir=examples/basic validate

terraform -chdir=examples/complete init -backend=false
terraform -chdir=examples/complete validate
```

Os testes usam provider AWS mockado e não criam infraestrutura nem precisam de credenciais.

## Migração da versão anterior

Esta atualização remove compatibilidade com AWS provider 4.x. Antes de adotar:

1. execute o plan com a versão anterior e confirme ausência de drift inesperado;
2. atualize Terraform e a constraint do provider no módulo raiz;
3. execute `terraform init -upgrade`;
4. revise o plan, especialmente tags, tipos antes representados como strings, regras dos Security Groups auxiliares e Transit Gateways configurados com `create = false`;
5. aplique primeiro em ambiente não produtivo.

O argumento removido `aws_eip.vpc` foi migrado para `domain = "vpc"`. Nenhum rename de endereço Terraform foi introduzido nos recursos existentes. Os antigos diretórios `test/`, que continham backends compartilhados e dados específicos de cliente, foram substituídos por `testing/` e `examples/` seguros por padrão.

## Limites atuais

- IPv6 está implementado para dual-stack; subnets exclusivamente IPv6 ainda não são suportadas.
- Flow Logs podem usar destinos centralizados existentes, mas o módulo não cria buckets S3, Firehose ou policies cross-account.
- Transit Gateway não cria RAM shares nem aceita attachments cross-account.
- NAT Instance depende de AMI mantida pelo consumidor e não oferece failover automático de rotas entre AZs; para esse requisito, prefira NAT Gateway ou uma solução de appliance dedicada.
- O repositório ainda não publica tags/releases, portanto consumidores externos não têm uma versão SemVer oficial para fixar.
- O repositório ainda não declara uma licença de software; a escolha deve ser feita pelos mantenedores antes de promover reutilização externa.

Esses itens devem ser tratados como evoluções separadas porque ampliam permissões, custo ou risco de recriação.

# Referência de configuração

Todo o contrato público entra no objeto `vpc_config`. Os exemplos abaixo omitem campos opcionais. `variables.tf` continua sendo a definição executável e deve ser consultado quando houver divergência.

## Campos de topo

| Campo | Tipo | Padrão | Uso |
|---|---|---|---|
| `vpc` | object | obrigatório | VPC nova por CIDR/IPAM ou VPC existente |
| `ipam` | object | `null` | Alias legado de `vpc.ipv4_ipam_pool_id` |
| `global` | object | `{}` | Tags compartilhadas e seleção global de AZs |
| `dhcp_options` | object | DNS da Amazon | DHCP options e servidores auxiliares |
| `igw` | object | `{ create = true }` | Internet Gateway criado ou existente |
| `ipv6` | object | desabilitado | Associação IPv6 e Egress-only IGW |
| `subnet_layers` | list(object) | `[]` | Subnets, route tables, rotas e NACLs |
| `nat_gateway` | object | desabilitado | NAT Gateways distribuídos por AZ |
| `nat_instance` | object | desabilitado | NAT Instances distribuídas por AZ |
| `flow_logs` | object | desabilitado | VPC Flow Logs |
| `security_groups` | list(object) | `[]` | Security Groups e regras explícitas |
| `vpc_endpoints` | map(object) | `{}` | Gateway, Interface e endpoint service |
| `peering_connection` | list(object) | `[]` | Request ou accept de peering e suas rotas |
| `transit_gateway` | map(object) | `{}` | TGWs, attachments e rotas |

## `vpc`

| Campo | Padrão | Observação |
|---|---|---|
| `create` | `true` | Cria a VPC; `false` referencia `vpc_id` |
| `cidr_block` | `null` | Exclusivo com `ipv4_ipam_pool_id` em VPC nova |
| `ipv4_ipam_pool_id` | `null` | Pool IPAM para IPv4 |
| `ipv4_netmask_length` | `20` | Usado somente com IPAM |
| `vpc_id` | `null` | Obrigatório quando `create = false` |
| `enable_dns_hostnames` | `true` | DNS hostnames da VPC |
| `enable_dns_support` | `true` | Resolução DNS da VPC |
| `enable_network_address_usage_metrics` | `false` | Métricas de uso de endereços |
| `instance_tenancy` | `default` | Tenancy da VPC |
| `tags` | `{}` | Tags específicas, aplicadas depois de `global.tags` |

Configure exatamente uma fonte IPv4 para uma VPC nova:

```hcl
vpc = {
  ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
  ipv4_netmask_length = 20
}
```

`ipam.ipam_pool_id` permanece funcional como alias de compatibilidade durante a v2, mas está deprecado. Não configure o alias junto com `vpc.cidr_block` ou `vpc.ipv4_ipam_pool_id`.

## `global`

`global.tags` é mesclado em recursos gerenciados. Tags mais específicas e o `Name` calculado podem sobrescrever chaves globais. O módulo não obriga tags organizacionais; use `provider.default_tags` no módulo raiz para um baseline obrigatório.

`global.az.state` filtra o estado das AZs e `global.az.exclude_zone_ids` remove Zone IDs globalmente. Prefira Zone IDs, que são estáveis entre contas, a nomes como `us-east-1a`.

## `subnet_layers`

Campos principais de cada camada:

| Campo | Padrão | Observação |
|---|---|---|
| `name` | obrigatório | Único no objeto; compõe as chaves dos recursos |
| `create` | `true` | Se falso, não cria subnet nem dependências da camada |
| `scope` | `private` | `public` habilita rotas de IGW |
| `az_widerange` | `3` | Quantidade de AZs quando `az_ids` não é informado |
| `az_ids` | `null` | Seleção explícita de Zone IDs |
| `cidr_block` | derivado | Um CIDR por AZ selecionada |
| `netprefix` | CIDR da VPC | Prefixo usado na derivação |
| `netlength` | `8` | Bits adicionais na derivação (`/16` vira `/24`) |
| `netnum` | automático | Primeiro índice da camada |
| `map_public_ip_on_launch` | `false` | Não é habilitado automaticamente por `scope` |
| `has_outbound_internet_access_via_natgw` | `false` | Exige `nat_gateway.create = true` |
| `has_outbound_internet_access_via_natinstance` | `false` | Exige `nat_instance.create = true` |
| `ipv6_enabled` | `true` | Efetivo somente quando `ipv6.enabled = true` |
| `ipv6_cidr_block` | derivado | Um `/64` por AZ quando omitido |
| `network_acl_rules` | `[]` | Regras stateless adicionais |
| `network_acl_quarentine` | `false` | Associa AZs selecionadas à default NACL bloqueada |
| `routes` | `[]` | Rotas IPv4 ad hoc por prefix list |
| `tags` | `{}` | Tags específicas da camada |

Os campos de DNS por subnet são `enable_dns64`, `enable_resource_name_dns_a_record_on_launch`, `enable_resource_name_dns_aaaa_record_on_launch` e `private_dns_hostname_type_on_launch`. `assign_ipv6_address_on_creation` é efetivo somente no dual-stack.

Uma rota ad hoc aceita `destination_cidr_block`, `target` e `az_ids`. Os targets reconhecidos pelo prefixo são `nat-`, `eni-`, `tgw-`, `vpce-`, `pcx-` e `eigw-`.

Uma regra de NACL aceita `action`, `egress`, `cidr_block` ou `ipv6_cidr_block`, `from_port`, `to_port`, `icmp_code`, `icmp_type`, `protocol` e `rule_no`. Regras stateless precisam cobrir ida, volta e portas efêmeras conforme o protocolo do workload.

> O nome `network_acl_quarentine` preserva a grafia legada para compatibilidade.

## Internet Gateway e IPv6

`igw.create` é `true` por padrão para VPC nova. Em VPC existente ou quando a criação for desabilitada, informe `igw.internet_gateway_id` se houver camada pública. `igw.vpc_id` permite indicar a VPC da associação em cenários legados.

| Campo IPv6 | Padrão | Observação |
|---|---|---|
| `enabled` | `false` | Habilita o caminho dual-stack |
| `assign_generated_ipv6_cidr_block` | `true` | Solicita `/56` da AWS em VPC nova |
| `ipv6_cidr_block` | `null` | CIDR explícito; obrigatório em VPC existente |
| `ipv6_ipam_pool_id` | `null` | Fonte IPv6 por IPAM |
| `ipv6_netmask_length` | `null` | Prefixo solicitado ao IPAM |
| `ipv6_pool` | `null` | Pool IPv6 da Amazon |
| `create_egress_only_internet_gateway` | `true` | Necessário para camadas privadas IPv6 |
| `egress_only_internet_gateway_id` | `null` | Alternativa exclusiva à criação |

O modo gerado é exclusivo com CIDR, IPAM e pool explícitos.

## NAT

`nat_gateway` e `nat_instance` aceitam `create`, `az_widerange`, `az_ids` e `exclude_az_ids`. Uma camada pública é candidata automaticamente; `nat_gw_scope` e `nat_instance_scope` existem para compatibilidade e seleção avançada.

NAT Gateway cria EIP e gateway por AZ selecionada. Uma subnet privada prefere o NAT Gateway da mesma AZ e usa o primeiro candidato somente como fallback.

NAT Instance exige `ami_id` válido. Também aceita `instance_type` (`t3.medium`), `key_name`, `iam_instance_profile_name`, `health_check_grace_period` (`300`) e `instance_tags`. `iam_instance_profile` é um alias de compatibilidade para `iam_instance_profile_name`; se ambos forem informados, precisam ter o mesmo valor. A AMI, IP forwarding, patching e hardening do sistema operacional pertencem ao consumidor.

## Flow Logs

| Campo | Padrão | Observação |
|---|---|---|
| `create` | `false` | Habilita um Flow Log no nível da VPC |
| `log_destination_type` | `cloud-watch-logs` | Também `s3` ou `kinesis-data-firehose` |
| `traffic_type` | `ALL` | `ACCEPT`, `REJECT` ou `ALL` |
| `max_aggregation_interval` | `60` | `60` ou `600` segundos |
| `log_destination_arn` | gerenciado no CloudWatch | Obrigatório para S3/Firehose |
| `iam_role_arn` | gerenciado no CloudWatch | Role existente opcional |
| `cloudwatch_log_group_name` | calculado | Nome do Log Group gerenciado |
| `cloudwatch_retention_in_days` | `90` | Retenção do Log Group gerenciado |
| `cloudwatch_kms_key_id` | `null` | Chave KMS do Log Group |
| `log_format` | padrão AWS | Formato customizado opcional |
| `destination_options` | `null` | Formato e particionamento para S3 |
| `tags` | `{}` | Tags do Flow Log e recursos gerenciados |

`destination_options` aceita `file_format` (`plain-text`), `hive_compatible_partitions` (`false`) e `per_hour_partition` (`false`).

## DHCP Options

Campos: `domain_name`, `domain_name_servers`, `ntp_servers`, `netbios_name_servers`, `netbios_node_type` e `tags`. O domínio padrão é `ec2.internal` em `us-east-1` e `<region>.compute.internal` nas demais regiões; DNS padrão é `AmazonProvidedDNS`.

## Security Groups

Cada item exige `name` e aceita `name_prefix`, `description`, `vpc_id`, `revoke_rules_on_delete`, `tags`, `ingress` e `egress`.

Cada regra exige `from_port`, `to_port` e `protocol`; as origens/destinos opcionais são `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, `source_security_group_id` e `self`. O módulo não adiciona egress implícito aos Security Groups configurados pelo consumidor.

## VPC Endpoints

O mapa é indexado pelo nome do serviço, por exemplo `s3` ou `ec2`.

- `service_type`: obrigatório; `Gateway`, `Interface` ou `endpointservice`.
- Gateway: use `route_table_ids`, `route_tables_filter` ou deixe ambos ausentes para usar as route tables criadas.
- Interface: use `subnet_ids` para seleção determinística ou `subnet_filter`; `az_ids` e `exclude_az_ids` refinam a busca.
- `listener_ports` controla porta, protocolo e Security Groups permitidos. Sem grupos explícitos, o CIDR da VPC é permitido.
- Também estão disponíveis `policy`, `auto_accept`, `private_dns_enabled`, `endpoint_service_private_dns_enabled`, `dns_options`, `ip_address_type` e `tags`.

## VPC Peering

Cada item configura exatamente uma operação:

- request: `peer_vpc_id`;
- accept: `vpc_peering_connection_id`.

Configure exatamente uma seleção de route tables: `route_table_ids` explícitos ou `route_tables_filter`. Para uma VPC criada pelo módulo, o filtro precisa ser baseado em tag e é resolvido contra as tags estáticas das route tables sem depender de IDs desconhecidos no plan; `tag:subnet_layer` e `tag:scope` são as opções usuais. Para uma VPC existente, o filtro consulta a AWS.

Ao menos um `cidr_blocks` é obrigatório. O módulo cria uma managed prefix list e rotas nas tabelas selecionadas. `peer_owner_id`, `peer_region`, `vpc_id`, `auto_accept`, `requester`, `accepter` e `tags` refinam a conexão. Peering cross-account não é autoaceito pelo requester.

## Transit Gateway

O mapa é indexado por um nome lógico. Cada item aceita criar o TGW ou referenciar `transit_gateway_id`. Os argumentos do gateway incluem ASN, opções de associação/propagação default, DNS, multicast, VPN ECMP, CIDRs e tags.

`vpc_attachment.create = true` cria o attachment. Se `subnet_ids` não for informado, `subnet_layer_names` seleciona camadas criadas; o padrão é `private`. O bloco também expõe DNS, IPv6, appliance mode, Security Group referencing e opções de associação/propagação.

`transit_gateway_routes` cria rotas no TGW. Rotas não blackhole usam o attachment deste módulo; para TGW existente, cada rota precisa de `transit_gateway_route_table_id`.

`vpc_routes` cria rotas nas route tables da VPC. Use `route_table_ids` explícitos ou `subnet_layer_names`.

## Tags e precedência

A precedência geral é `global.tags`, tags do bloco/recurso e tags calculadas pelo módulo. O `Name` calculado pode sobrescrever um `Name` global. Para governança obrigatória e consistente, configure `default_tags` no provider do módulo raiz.

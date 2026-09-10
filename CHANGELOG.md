# Changelog

Todas as mudanças relevantes deste projeto serão registradas neste arquivo. O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e as releases planejadas seguem versionamento semântico.

## [Unreleased]

### Added

- VPC Flow Logs para CloudWatch Logs, S3 e Firehose.
- IPv6 dual-stack, Egress-only Internet Gateway e rotas IPv6.
- Transit Gateway com attachments e rotas TGW/VPC.
- NAT Gateway e NAT Instance com seleção por AZ.
- Outputs de consumo, exemplos seguros, testes mockados e CI.
- Documentação de arquitetura, configuração, migração, contribuição, segurança e instruções para agentes.

### Changed

- AWS provider mínimo atualizado para 6.0.0.
- Contrato `vpc_config` tipado e validado com mais rigor.
- Derivação automática de CIDRs tornada determinística por camada.
- NAT Instance passa a exigir AMI mantida pelo consumidor e IMDSv2.

### Fixed

- Domínio DHCP regional e configuração de NTP.
- Comportamento de VPC existente, peering, endpoints e Security Groups opcionais.
- Alias legado `ipam.ipam_pool_id`, que existia no contrato mas não era aplicado à VPC.
- Planejamento de rotas de peering em VPC recém-criada, sem `for_each` dependente de IDs desconhecidos.
- Conflito do provider entre IPv6 gerado e associação IPv6 explícita/IPAM.
- Argumento removido de `aws_eip` substituído por `domain = "vpc"`.

### Removed

- Diretório de testes legado com backends/dados específicos e binário versionado.
- Importador obsoleto de NAT AMI.

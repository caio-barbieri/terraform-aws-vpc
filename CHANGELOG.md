# Changelog

Todas as mudanças relevantes deste projeto serão registradas neste arquivo. O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e as releases planejadas seguem versionamento semântico.

## [2.0.0](https://github.com/opsteamhub/terraform-aws-vpc/compare/v1.0.0...v2.0.0) (2026-09-10)


### ⚠ BREAKING CHANGES

* **vpc:** require AWS provider 6.x and adopt stricter typed inputs and validation for the vpc_config contract.

### Features

* **vpc:** prepare module v2 ([04ccbbb](https://github.com/opsteamhub/terraform-aws-vpc/commit/04ccbbbfc1bbc7e958613267fdd314cd2f58a961))


### Bug Fixes

* **nat_instance:** propagate key_name, iam_instance_profile and instance_tags ([204b5e9](https://github.com/opsteamhub/terraform-aws-vpc/commit/204b5e9dedbe29647ffbf87c2a0e04ec232d7cd4))
* **nat-instance:** preserve access inputs during main merge ([11cf9f1](https://github.com/opsteamhub/terraform-aws-vpc/commit/11cf9f1192a37f6d3d6946893cea023ee4c15dd5))
* **vpc:** harden IPAM IPv6 and peering paths ([3d6c91f](https://github.com/opsteamhub/terraform-aws-vpc/commit/3d6c91f49f9b08290ddba375034baf5a247ba8a4))

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

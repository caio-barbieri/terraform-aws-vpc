# Migração para v2

Este guia prepara a adoção da próxima versão major. Enquanto `v2.0.0` não for publicada, fixe o consumo no SHA do commit revisado do PR; não use uma branch mutável em produção.

## Principais mudanças

- AWS provider 4.x deixa de ser suportado; a linha v2 exige AWS provider 6.x.
- Campos antes permissivos passam a ter tipos e validations estritos.
- `aws_eip` usa `domain = "vpc"` no lugar do argumento removido `vpc`.
- VPC existente exige `vpc_id` e passa a ser consultada para obter contexto de CIDR/ARN.
- CIDRs automáticos são determinísticos por ordem de camada, com `netlength = 8` por padrão.
- NAT Gateway e NAT Instance passam a preferir recursos na mesma AZ.
- `ipam.ipam_pool_id` passa a funcionar como alias de compatibilidade, mas novos consumidores devem usar `vpc.ipv4_ipam_pool_id`.
- Os antigos diretórios `test/`, com backends e dados específicos, foram substituídos por exemplos sem backend e testes mockados.

Não há rename intencional de endereços Terraform nos recursos existentes. Mesmo assim, alterações de tipos, defaults e bugs corrigidos podem produzir mudanças no plan.

## Pré-requisitos

1. Confirme um backup recuperável do state e o lock funcionando.
2. Execute plan com a versão atual do módulo e elimine drift não relacionado.
3. Escolha uma conta e um state de sandbox inequívocos.
4. Atualize o módulo raiz para Terraform compatível e AWS provider 6.x.
5. Fixe a origem do módulo em tag ou SHA; nunca valide migração contra `main` mutável.
6. Migre `ipam.ipam_pool_id` para `vpc.ipv4_ipam_pool_id` quando esse alias legado estiver em uso.

## Procedimento

```bash
terraform init -upgrade
terraform validate
terraform plan -out=v2-migration.tfplan
terraform show v2-migration.tfplan
```

No plan, revise explicitamente:

- substituição ou alteração de VPC, subnets, route tables e associações;
- ordem de `subnet_layers`, `az_widerange`, `az_ids`, CIDRs, `netlength` e `netnum`;
- default NACL, NACLs das camadas e default Security Group;
- Internet Gateway, Egress-only Internet Gateway e rotas IPv4/IPv6;
- quantidade e mapeamento por AZ de EIPs, NAT Gateways e NAT Instances;
- destinos, role, retenção e criptografia de Flow Logs;
- seleção por filtro/IDs, managed prefix lists e rotas de peering;
- attachments e rotas Transit Gateway;
- tags que possam disparar policies ou automações externas;
- recursos com custo novo.

Faça apply primeiro em sandbox, valide conectividade e observabilidade e só depois promova a mesma versão imutável aos demais ambientes.

## VPC existente

Use:

```hcl
vpc = {
  create = false
  vpc_id = "vpc-0123456789abcdef0"
}
```

O módulo não assume ownership dos recursos default da VPC existente. Se houver camada pública, forneça `igw.internet_gateway_id`. Em IPv6, forneça `ipv6.ipv6_cidr_block` e escolha exatamente entre criar ou referenciar o Egress-only Internet Gateway quando existirem camadas privadas.

## Rollback

Antes de qualquer apply, rollback significa restaurar a versão anterior do módulo e o lockfile, executar `terraform init` e confirmar o plan.

Depois de um apply, não restaure state manualmente sem análise. Fixe novamente a versão anterior, gere um plan de rollback e revise substituições. Se a v2 já criou recursos stateful ou alterou endereçamento, trate o rollback como mudança de rede e não como simples reversão de Git.

## Gate de release

`v2.0.0` só deve ser publicada após:

- CI verde;
- plan de migração revisado em sandbox real;
- apply e smoke test de conectividade no sandbox;
- documentação e changelog revisados;
- decisão do mantenedor sobre a licença do repositório.

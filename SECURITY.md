# Política de segurança

## Como reportar

Não abra issue pública para vulnerabilidades, credenciais expostas ou caminhos de ataque. Use o fluxo privado de [GitHub Security Advisories](https://github.com/opsteamhub/terraform-aws-vpc/security/advisories/new). Se ele não estiver disponível para sua conta, contate privadamente um mantenedor da organização OpsTeamHub e inclua somente os dados mínimos necessários.

Informe a versão ou SHA afetada, impacto, pré-condições, passos de reprodução seguros e uma sugestão de mitigação. Não inclua credenciais reais, state Terraform, dados de clientes ou provas executadas em produção.

## Escopo de suporte

Antes da primeira release versionada, correções são mantidas em `main`. Depois da publicação da v2, a versão major mais recente será a linha suportada; versões anteriores dependem de uma decisão explícita dos mantenedores.

## Modelo de responsabilidade

O consumidor é responsável por credenciais, IAM, região, backend/state, policies organizacionais, tags obrigatórias, AMI de NAT Instance, destinos externos de Flow Logs e validação em sua conta. Um exemplo funcional não substitui análise de ameaça, revisão de plan nem testes de conectividade do ambiente.

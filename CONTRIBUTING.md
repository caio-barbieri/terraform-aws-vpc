# Contribuindo

## Preparação

Use Terraform 1.7 ou superior para executar testes mockados. CI usa versões fixadas no workflow. O módulo não precisa de credenciais AWS para validação local.

```bash
terraform init -backend=false -input=false
terraform validate
terraform test -test-directory=testing
```

Não adicione provider ou backend ao módulo raiz. Exemplos devem continuar sem backend remoto, segredos ou IDs de clientes.

## Desenvolvimento

1. Abra uma branch curta a partir de `main`.
2. Preserve os endereços Terraform existentes ou documente claramente a migração.
3. Atualize `variables.tf`, `docs/CONFIGURATION.md` e os exemplos quando alterar o contrato.
4. Adicione testes positivos e negativos para novos comportamentos e validations.
5. Registre mudanças de consumo em `CHANGELOG.md` e `docs/MIGRATION-v2.md` quando aplicável.
6. Use Conventional Commits em inglês.

## Verificação

Execute todos os comandos listados em [AGENTS.md](AGENTS.md). Os testes em `testing/` usam provider mockado; eles validam o grafo e os contratos, mas não substituem um plan/apply controlado em sandbox para uma release major.

## Pull request

O PR deve explicar comportamento, compatibilidade, custo, segurança, testes e rollback. Inclua um plan de sandbox quando a mudança puder substituir recursos ou alterar conectividade. Não publique tag/release antes da aprovação e do merge.

# Repository instructions

This repository contains a reusable Terraform module for AWS VPC networking. Treat `variables.tf` as the input contract, `outputs.tf` as the output contract, and the files under `docs/` as the design and migration record.

## Working rules

- Keep the module provider- and backend-agnostic. Provider configuration, credentials, region, state, and locking belong to the root module.
- Never run `terraform apply` against a real AWS account while developing this module. The automated tests use a mocked AWS provider and require no credentials.
- Do not commit state, plans, provider binaries, credentials, customer identifiers, or backend configuration.
- Preserve existing resource addresses unless a breaking change is intentional and documented in `docs/MIGRATION-v2.md`.
- Add variable validation for invalid input combinations and add both a positive and a negative test when changing a contract.
- Keep examples safe by default: no remote backend, no secrets, and no environment-specific identifiers.
- Prefer small, reviewable pull requests. Do not create a tag or release from a feature branch.
- Use Conventional Commits in English.

## Required checks

Run these commands from the repository root before proposing a change:

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform test -test-directory=testing

terraform -chdir=examples/basic init -backend=false -input=false
terraform -chdir=examples/basic validate
terraform -chdir=examples/complete init -backend=false -input=false
terraform -chdir=examples/complete validate

tflint --init
tflint --recursive --format compact
trivy config --severity HIGH,CRITICAL --exit-code 1 .
```

Validate the repository agent configuration against its pinned schema:

```bash
check-jsonschema \
  --schemafile "$(jq -r '.\"$schema\"' .kiro/agents/local-agent.json)" \
  .kiro/agents/local-agent.json
```

Terraform provider mocking requires Terraform 1.7 or newer. CI is the source of truth for the exact tool versions.

## Review focus

Network changes have a large blast radius. Review plans for replacement of VPCs, subnets, route tables, gateways, NACLs, peering connections, and Transit Gateway attachments. Verify IPv4 and IPv6 paths independently, and call out any cost-bearing resource such as NAT Gateway, Flow Logs storage, or Transit Gateway.

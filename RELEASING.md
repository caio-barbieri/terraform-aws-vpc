# Releases

This module uses Semantic Versioning and Release Please. Releases are created only
from the default branch after a release pull request is reviewed and merged.

## Compatibility baseline

The first successful `Release` workflow run creates `v1.0.0` at the audited legacy
commit recorded as `bootstrap-sha` in `release-please-config.json`. It never points
that tag at the release-automation commit or at the breaking v2 implementation.
The workflow refuses to move `v1.0.0` if the tag already exists at another commit.

Before merging a breaking v2 pull request, every active consumer of the unversioned
default branch must pin the compatibility baseline:

```hcl
module "vpc" {
  source = "git::ssh://git@github.com/opsteamhub/terraform-aws-vpc.git?ref=v1.0.0"
}
```

A consumer that keeps using a branch or omits `ref` is still exposed to breaking
changes. Creating releases alone does not protect that consumer.

## Version rules

- `fix:` creates a patch release.
- `feat:` creates a minor release.
- `feat!:` or a `BREAKING CHANGE:` footer creates a major release.
- Documentation, CI, tests, and chores do not create a release by themselves.

Pull request titles must use Conventional Commits because the squash-merge title is
the release signal. Release Please opens a normal, non-draft release pull request,
updates `CHANGELOG.md`, and creates the tag and GitHub Release only after that pull
request is merged.

## Repository setup

The repository must allow GitHub Actions to write contents and pull requests. Add a
`RELEASE_PLEASE_TOKEN` Actions secret backed by a GitHub App or fine-grained token
with contents, issues, and pull-request write permissions so release PRs trigger
the normal validation workflows. Without it, the workflow falls back to
`GITHUB_TOKEN`, whose pull requests do not trigger other workflows.

Tags are immutable. Never move or delete a published version to correct a release;
publish a new patch version instead.

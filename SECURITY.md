# Security policy (org-wide)

This policy applies to **every repository under the [NexusFFXIV](https://github.com/NexusFFXIV) org** unless that repo overrides it with its own `SECURITY.md`.

## Reporting a vulnerability

Please **do not** open a public GitHub Issue for security vulnerabilities. Use the **private vulnerability-reporting** feature instead:

1. Go to the affected repo's **Security** tab.
2. Click **"Report a vulnerability"** under "Advisories".
3. Fill in the form. The maintainers get a private notification — no public disclosure until we coordinate it together.

Direct link patterns (replace `<repo>`):
```
https://github.com/NexusFFXIV/<repo>/security/advisories/new
```

If GitHub's reporting UI is unavailable to you, contact the maintainer directly via the email listed on the [Opachl GitHub profile](https://github.com/Opachl).

## What we ask

- **Don't** post proof-of-concept exploits to public Issues, Discussions, or social media before we've had a chance to triage.
- Include enough detail to reproduce: affected component(s), version(s), steps, and impact assessment.
- If you have a patch in mind, you're welcome to attach it — but it isn't required.

## What we'll do

- Acknowledge within **72 hours** of receipt.
- Investigate and confirm (or refute) within **14 days** for normal-severity issues; faster for critical ones.
- Coordinate a disclosure timeline with you — typically 30–90 days from confirmation, depending on severity and patch readiness.
- Credit you in the release notes / advisory if you'd like (or keep you anonymous if you prefer).

## Supported versions

| Version | Security fixes |
|---------|----------------|
| Latest stable (`vX.Y.Z`) | ✅ |
| Latest pre-release (`vX.Y.Z-rc.N`) | ⚠️ best-effort |
| Older minor versions | ❌ |

NexusFFXIV is in active development; we don't backport security fixes to versions older than the latest stable minor. Upgrading is the supported remediation.

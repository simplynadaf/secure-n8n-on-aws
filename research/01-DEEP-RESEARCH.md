# Deep Research - Secure / Harden Self-Hosted n8n on AWS

Verified 2026-09-07 against primary sources (NVD/vendor CVE pages + n8n GitHub advisory +
a hardening checklist). Every claim in this repo and the companion video traces back to
this doc. Content from sources was rephrased for compliance with licensing restrictions.

## The narrative (what the episode proves)
Most n8n self-host tutorials optimize for convenience: port 5678 open, default settings,
secrets in plaintext env. In 2026 that is dangerous. We show the risky-default setup,
demonstrate a real class of exposure, then harden it on AWS with a concrete checklist and
show the fix.

## Verified CVE facts (re-verify at record/publish time)
### CVE-2026-65589 - the anchor CVE
- Type: Information Disclosure (CWE-532, sensitive info written to logs/records).
- Affected: n8n **prior to 1.123.64**. Fixed in **1.123.64**.
- What: credentials passed as CUSTOM HTTP HEADERS inside LLM sub-node executions are not
  masked; n8n writes the plaintext API key / bearer token straight into the workflow
  EXECUTION RECORDS. Any authenticated user who can view executions (UI or API) can read
  them; exported execution archives carry the same exposure.
- Severity: CVSS 5.1 (MEDIUM). Not known-exploited. No public PoC.
- Fix/mitigations (official): upgrade to >= 1.123.64; rotate any key that was passed via
  a custom LLM header; purge/scrub old execution records; use n8n's built-in credential
  objects instead of custom headers; restrict who can read/export executions; reduce
  execution retention.
- Source of truth: n8n GitHub Security Advisory GHSA-89gh-3pgc-v5h2; SentinelOne CVE page.

### Context CVEs (mention as "n8n had a rough 2026"; do not detail unless re-verified)
- Reports cite multiple CVEs assigned to n8n in 2026, including critical sandbox-escape
  issues (server takeover / credential theft on self-hosted and cloud).
- Also reported: leaked n8n API tokens exposing live instances to credential theft;
  weak-encryption-key recovery from public artifacts (internet-exposed instances with
  known weak keys); a surge in phishing abusing n8n infrastructure.
- RULE: only state a specific CVE number/score if re-verified on the day of publishing.
  Otherwise say "multiple critical CVEs in 2026" and cite the category, not a number.

## Why n8n is a high-value target (one line)
n8n is a credential aggregator: one instance can hold API keys/tokens/DB strings for
Stripe, HubSpot, Postgres, Slack, Google, etc. Compromise it and you get all of them.
Exposed instances are indexed by internet scanners regularly.

## The hardening checklist we demonstrate on AWS
Server (EC2 / OS):
1. Security group: allow only 22 (locked to your IP), 80, 443. NEVER expose 5678.
   (An AWS security group is the cloud equivalent of a default-deny host firewall.)
2. SSH keys only, disable root login / password auth, MaxAuthTries 3.
3. Unattended security updates.

n8n config (.env / compose env):
4. Set N8N_ENCRYPTION_KEY = `openssl rand -hex 32`. Without it n8n uses a default/derived
   key = effectively no encryption. Back it up separately; losing it = losing all creds.
5. Disable public sign-up after the first admin (invite-only).
6. WEBHOOK_URL = https://... (many providers refuse http webhooks; also avoids
   localhost:5678 URLs behind a proxy).
7. Session timeout: N8N_USER_MANAGEMENT_JWT_DURATION_HOURS=2.
8. Prune execution data: EXECUTIONS_DATA_PRUNE=true, EXECUTIONS_DATA_MAX_AGE=168 (or 24
   for sensitive). For the CVE class, EXECUTIONS_DATA_SAVE_ON_SUCCESS=none can also help.
9. Disable telemetry: N8N_DIAGNOSTICS_ENABLED=false.
10. PATCH: pin an n8n image >= 1.123.64 (fixes CVE-2026-65589). Show the version.

Network:
11. Port 5678 NOT published to host; only the reverse proxy publishes 80/443. Verify:
    `curl -v http://<PUBLIC_IP>:5678` from outside must fail.
12. Restrict the editor UI by IP (or VPN); leave only /webhook/* public.
13. Rate-limit webhook paths.

Credentials (the AWS-native upgrade over a generic guide):
14. Put infra secrets (encryption key, DB password) in AWS Secrets Manager, injected at
    deploy, NOT committed and NOT plaintext in the repo. A `.env` on disk = chmod 600.
15. Prefer OAuth over static API keys; least-privilege scopes; rotate on a schedule.
16. Use n8n's built-in credential objects, NOT custom HTTP headers for LLM nodes
    (the direct mitigation for CVE-2026-65589).

AWS-native framing (why "on AWS" beats a generic VPS guide):
- Security group = default-deny firewall managed by AWS.
- Secrets Manager = managed secret store + rotation, instead of plaintext env.
- IAM least-privilege = if n8n talks to AWS, give it a scoped role, separate from any
  human/caller credential.
- Private subnet + ALB/reverse proxy + TLS = do not put the instance on a bare public IP.

## Safety rules
- Only FAKE credentials on screen (`sk-DEMO-...`). Never a real key/token.
- Use a throwaway/scratch instance and demo AWS resources; tear down after.
- This is a HARDENING demo, not an exploit tutorial - show the misconfig and the fix, not
  a working attack against anyone else's instance.
- Re-verify CVE-2026-65589 details (version, score) before stating them publicly.

## Sources (verified 2026-09-07, rephrased for compliance)
- SentinelOne - CVE-2026-65589 (version <1.123.64, CWE-532, CVSS 5.1, fix 1.123.64):
  https://www.sentinelone.com/vulnerability-database/cve-2026-65589/
- n8n GitHub Security Advisory GHSA-89gh-3pgc-v5h2 (authoritative fix/release):
  https://github.com/n8n-io/n8n/security/advisories/GHSA-89gh-3pgc-v5h2
- massivegrid - n8n production hardening checklist (encryption key, 5678, reverse proxy,
  IP whitelist, execution pruning, .env chmod 600):
  https://massivegrid.com/blog/n8n-security-hardening-checklist/
- The Hacker News - leaked n8n API tokens / credential theft:
  https://thehackernews.com/2026/08/leaked-n8n-api-tokens-exposed-live.html
- GitGuardian - weak encryption key recovery, exposed instances:
  https://blog.gitguardian.com/n8n-security-encryption-key-compromise/
- Pillar Security - sandbox escape -> takeover:
  https://www.pillar.security/blog/n8n-sandbox-escape-critical-vulnerabilities-in-n8n
- beyondscale - AI workflow automation security overview (n8n CVE context):
  https://beyondscale.tech/blog/ai-workflow-automation-security-n8n-zapier-make

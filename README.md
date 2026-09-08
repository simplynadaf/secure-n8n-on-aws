# Secure Self-Hosted n8n on AWS (2026)

Most n8n self-host tutorials optimize for convenience: port 5678 open, default settings,
secrets in plaintext. In 2026 that is dangerous - n8n saw multiple critical CVEs, leaked
API tokens exposing live instances, and weak-encryption-key recovery from public
artifacts. n8n is a **credential aggregator**: one instance can hold the keys to Stripe,
your database, Slack, Google, and more. Compromise it and you get all of them.

This repo shows the risky default setup, then hardens it on AWS with a concrete checklist.

> Companion to the video "Secure Self-Hosted n8n on AWS (2026)". Read `HARDENING.md`.

## What's here
```
insecure/docker-compose.yml     # the "before" - insecure ON PURPOSE, do not deploy
hardened/docker-compose.yml     # the "after" - n8n behind Caddy, patched, no exposed 5678
hardened/Caddyfile              # TLS + IP-restricted editor, public webhooks only
hardened/.env.example           # the env vars the hardened compose expects
iam/n8n-instance-role-policy.json   # least-privilege role: read only the two n8n secrets
scripts/create-secrets.sh       # store encryption key + DB password in AWS Secrets Manager
scripts/load-secrets.sh         # load secrets from Secrets Manager, bring up hardened stack
scripts/verify-hardening.sh     # verify from outside (5678 closed, HTTPS up)
SETUP.md                        # follow-along: build the box from zero (Docker + Compose)
HARDENING.md                    # the full checklist with the WHY for each item
research/01-DEEP-RESEARCH.md    # verified CVE facts + sources behind every claim
```

## The 60-second version
1. Patch: run n8n **>= 1.123.64** (fixes CVE-2026-65589).
2. Never expose 5678; put n8n behind Caddy on 443 with TLS.
3. Restrict the editor UI by IP; leave only `/webhook/*` public.
4. Set a real `N8N_ENCRYPTION_KEY`; keep it + the DB password in **AWS Secrets Manager**.
5. Give the EC2 instance a **least-privilege IAM role** that reads only those secrets.
6. Prune execution data; use built-in credential objects (not custom LLM headers).

## Follow along (the exact steps from the video)
Starting from a fresh Amazon Linux 2023 EC2 instance:

```bash
# 1. Install Docker + the Compose plugin (see SETUP.md for the full commands)
sudo dnf install -y docker
sudo systemctl enable --now docker

# 2. (the "before") run the insecure stack and see 5678 open to the world - DO NOT keep this up
sudo docker compose -f insecure/docker-compose.yml up -d
curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://<PUBLIC_IP>:5678   # 200 = reachable by anyone

# 3. tear it down before going further
sudo docker compose -f insecure/docker-compose.yml down
```

Full, copy-pasteable setup (Docker version pin, Compose plugin install, group perms) is in
[`SETUP.md`](SETUP.md).

## Quick start (hardened)
```bash
# once, from an admin session:
AWS_REGION=us-east-1 ./scripts/create-secrets.sh

# on the EC2 instance (edit N8N_HOST + Caddyfile domain/IP first):
N8N_HOST=n8n.yourdomain.com ./scripts/load-secrets.sh

# from another machine:
./scripts/verify-hardening.sh <PUBLIC_IP> n8n.yourdomain.com
```

The hardened stack reads three env vars (`N8N_HOST`, `N8N_ENCRYPTION_KEY`,
`POSTGRES_PASSWORD`). `load-secrets.sh` pulls the last two from AWS Secrets Manager at
runtime so they never touch disk. See [`hardened/.env.example`](hardened/.env.example) for
what each one is - do NOT commit a real `.env`.

## The CVE this fixes (CVE-2026-65589)
n8n versions before 1.123.64 wrote credentials passed as **custom HTTP headers in LLM
sub-nodes** into workflow execution records in plaintext (CWE-532). Any authenticated
user who could view or export executions could harvest them. Fix: upgrade to >= 1.123.64,
rotate exposed keys, purge old execution data, and use built-in credential objects
instead of custom headers. Source: n8n advisory GHSA-89gh-3pgc-v5h2. Full verified facts
and sources: [`research/01-DEEP-RESEARCH.md`](research/01-DEEP-RESEARCH.md).

## Safety note
`insecure/` is intentionally vulnerable to demonstrate the problem. Do not deploy it.
Use only fake credentials (e.g. `sk-DEMO-...`) when reproducing the leak.

## License
MIT - see LICENSE.

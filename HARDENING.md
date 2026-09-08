# n8n on AWS - Hardening Checklist

Work top to bottom. Each item says WHY it matters. Verified against n8n's own advisories
and a production hardening checklist (see research/01-DEEP-RESEARCH.md for sources).

## 0. Patch first
- [ ] Run n8n **>= 1.123.64**. Versions before that are affected by **CVE-2026-65589**
      (plaintext API keys from LLM sub-node custom HTTP headers written into execution
      records, CWE-532). The `hardened/` compose pins a fixed version; `insecure/` pins
      an old one on purpose.

## 1. AWS network (the cloud firewall)
- [ ] Security group allows only: 22 (locked to YOUR IP), 80, 443. **Never** 5678.
- [ ] Instance in a private subnet where possible; public entry only via ALB / reverse proxy.
- [ ] Verify from outside: `curl -v http://<PUBLIC_IP>:5678` must time out / refuse.

## 2. Server / OS
- [ ] SSH keys only; disable root login and password auth; MaxAuthTries 3.
- [ ] Unattended security updates enabled.

## 3. n8n config
- [ ] `N8N_ENCRYPTION_KEY` set to `openssl rand -hex 32`. Without it, n8n uses a
      default/derived key = creds effectively unencrypted. Back the key up separately;
      losing it = losing every stored credential.
- [ ] Public sign-up disabled after the first admin (invite-only).
- [ ] `WEBHOOK_URL=https://your.domain/` (providers reject http; avoids localhost URLs).
- [ ] `N8N_USER_MANAGEMENT_JWT_DURATION_HOURS=2` (session timeout).
- [ ] `EXECUTIONS_DATA_PRUNE=true`, `EXECUTIONS_DATA_MAX_AGE=168` (or 24 for sensitive).
- [ ] `N8N_DIAGNOSTICS_ENABLED=false` (telemetry off).

## 4. Reverse proxy + TLS (Caddy)
- [ ] n8n has NO published `ports:`; only Caddy publishes 80/443.
- [ ] TLS terminated at Caddy (auto HTTPS for a real domain).
- [ ] Editor UI + REST API restricted by IP (or VPN); only `/webhook/*` left public.
- [ ] Rate-limit webhook paths.

## 5. Secrets (AWS-native)
- [ ] Encryption key + DB password in **AWS Secrets Manager**, injected at runtime by
      `scripts/load-secrets.sh`. Never committed, never plaintext in the repo.
- [ ] EC2 instance uses a **least-privilege IAM role** that can read only those two
      secrets (see `iam/n8n-instance-role-policy.json`), separate from any human/caller
      credential.
- [ ] If a `.env` file is used on disk: `chmod 600 .env && chown root:root .env`.

## 6. Credentials inside n8n
- [ ] Use n8n's built-in **credential objects**, NOT custom HTTP headers for LLM nodes
      (direct mitigation for CVE-2026-65589).
- [ ] Prefer OAuth over static API keys; least-privilege scopes; rotate on a schedule.

## 7. Monitoring
- [ ] Review the Executions tab for odd times / unknown webhook sources / volume spikes.
- [ ] External uptime check on the HTTPS endpoint.
- [ ] Rotate + centralize Docker logs.

## Verify
Run from another machine: `scripts/verify-hardening.sh <PUBLIC_IP> <DOMAIN>`

<div align="center">

# 🔒 Secure Self-Hosted n8n on AWS (2026)

### Run n8n the way most tutorials tell you to, watch it expose itself to the internet, then harden it live on AWS - patched image, no public port, TLS, Secrets Manager, least-privilege IAM.

[![n8n](https://img.shields.io/badge/Automates-n8n-EA4B71?style=for-the-badge&logo=n8n&logoColor=white)](https://n8n.io)
[![AWS](https://img.shields.io/badge/Runs%20on-AWS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Caddy](https://img.shields.io/badge/TLS-Caddy-1F88C0?style=for-the-badge&logo=caddy&logoColor=white)](https://caddyserver.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

[![Stars](https://img.shields.io/github/stars/simplynadaf/secure-n8n-on-aws?style=social)](https://github.com/simplynadaf/secure-n8n-on-aws/stargazers)
[![Forks](https://img.shields.io/github/forks/simplynadaf/secure-n8n-on-aws?style=social)](https://github.com/simplynadaf/secure-n8n-on-aws/network/members)
[![Issues](https://img.shields.io/github/issues/simplynadaf/secure-n8n-on-aws)](https://github.com/simplynadaf/secure-n8n-on-aws/issues)

---

**⭐ If this helped you lock down your n8n, give it a star! It helps others find it.**

[The Problem](#-the-problem) • [The 4 Fixes](#-the-4-fixes) • [Getting Started](#-getting-started) • [Before vs After](#-before-vs-after) • [Hardening Checklist](#-hardening-checklist) • [FAQ](#-faq) • [Contributing](#-contributing)

</div>

<details>
<summary><b>📖 Table of Contents</b></summary>

- [The Problem](#-the-problem)
- [The 4 Fixes](#-the-4-fixes)
- [How It Works](#-how-it-works)
- [Tech Stack](#-tech-stack)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [Before vs After](#-before-vs-after)
- [Example: proving the exposure, then closing it](#-example-proving-the-exposure-then-closing-it)
- [Project Structure](#-project-structure)
- [Least-Privilege IAM Policy](#-least-privilege-iam-policy)
- [The CVE this fixes](#-the-cve-this-fixes-cve-2026-65589)
- [Hardening Checklist](#-hardening-checklist)
- [Customization](#-customization)
- [Troubleshooting](#-troubleshooting)
- [Security & Responsible Disclosure](#-security--responsible-disclosure)
- [FAQ](#-faq)
- [Video Tutorial & Article](#-video-tutorial--article)
- [Contributing](#-contributing)
- [License](#-license)

</details>

---

## 🤔 The Problem

n8n is a **credential aggregator**: one instance can hold the keys to Stripe, your database, Slack, Google, and dozens of other services. Compromise it and you get all of them at once.

Most self-host tutorials optimize for convenience - port `5678` open to the world, no encryption key, an old image, secrets in plaintext. In 2026 that is dangerous: n8n saw multiple critical CVEs, leaked API tokens exposing live instances, and weak-encryption-key recovery from public artifacts.

**This repo shows the risky default setup, proves the exposure, then hardens it on AWS with a concrete, verifiable checklist.**

> ⚠️ The `insecure/` stack is intentionally vulnerable to demonstrate the problem. **Do not deploy it.** Use only fake credentials (e.g. `sk-DEMO-...`) when reproducing the issue.

---

## ✨ The 4 Fixes

> One insecure setup. Four fixes. Every item verified live.

<table>
<tr>
<td width="25%">

### 🩹 Fix 1: Patch + Close 5678
- Pin n8n **>= 1.123.64** (fixes CVE-2026-65589)
- `expose` instead of `ports` - n8n reachable only inside Docker
- Nothing published on `5678`

</td>
<td width="25%">

### 🔑 Fix 2: Secrets Manager
- `N8N_ENCRYPTION_KEY` + DB password generated with `openssl`
- Stored in **AWS Secrets Manager**
- Injected at runtime, never in the repo, never plaintext

</td>
<td width="25%">

### 🛡️ Fix 3: Least-Privilege IAM
- Instance role reads **only** the two n8n secrets
- `GetSecretValue` + `DescribeSecret`, scoped to their ARNs
- Separate from any human credential

</td>
<td width="25%">

### 🌐 Fix 4: TLS + IP Lock (Caddy)
- Only Caddy publishes `80/443`, TLS auto via Let's Encrypt
- Editor + REST API restricted to your admin IP
- Only `/webhook/*` stays public

</td>
</tr>
</table>

---

## 🧠 How It Works

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                                │
│   🌍 Internet             🧱 AWS + Caddy edge            🔒 Private n8n         │
│                                                                                │
│   ┌──────────────┐    ┌───────────────────────────┐    ┌──────────────────┐  │
│   │ admin IP     │───▶│ Caddy :443 (TLS)           │───▶│ n8n  (expose only)│  │
│   │ webhooks     │    │  /webhook/*   → public     │    │ Postgres          │  │
│   │ attackers ✗  │    │  everything else → your IP │    │ (no public port)  │  │
│   └──────────────┘    └───────────────────────────┘    └──────────────────┘  │
│                                   │                                            │
│                                   ▼                                            │
│                        🔐 AWS Secrets Manager                                  │
│                        (encryption key + DB password)                          │
│                        read via least-privilege IAM role                       │
│                                                                                │
│   Security Group: only 22 (your IP), 80, 443 open.  5678 = CLOSED.             │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Why "on AWS" beats a generic VPS guide:** the Security Group is a managed default-deny firewall, Secrets Manager is a managed secret store with rotation, and an IAM least-privilege role scopes access without any static credentials.

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| ⚙️ Automation | [n8n](https://n8n.io) - `>= 1.123.64` (patched) |
| ☁️ Cloud | [AWS](https://aws.amazon.com) EC2 (Amazon Linux 2023) |
| 📦 Runtime | [Docker Compose](https://docs.docker.com/compose/) |
| 🌐 Reverse Proxy + TLS | [Caddy 2](https://caddyserver.com) - auto HTTPS, IP allow-list |
| 🗄️ Database | [PostgreSQL 16](https://www.postgresql.org) (no public port) |
| 🔐 Secrets | [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) |
| 🛡️ Access | IAM least-privilege instance role |

---

## 📋 Prerequisites

- ✅ A throwaway / scratch **Amazon Linux 2023** EC2 instance (`ec2-user`)
- ✅ SSH access via your key
- ✅ AWS CLI (preinstalled on Amazon Linux) + an admin session or instance role that can call Secrets Manager
- ✅ (For real TLS) a domain name you can point at the instance

---

## 🚀 Getting Started

### 1. Clone the repo (on the EC2 instance)

```bash
git clone https://github.com/simplynadaf/secure-n8n-on-aws.git
cd secure-n8n-on-aws
```

### 2. Install Docker + the Compose plugin

```bash
sudo dnf install -y docker
sudo systemctl enable --now docker
# full commands (incl. the Compose plugin) are in SETUP.md
```

> 💡 Full, copy-pasteable setup from a fresh box is in [`SETUP.md`](SETUP.md).

### 3. See the problem (the "before" - do NOT keep this up)

Bring the insecure stack up:

```bash
sudo docker compose -f insecure/docker-compose.yml up -d
```

Give n8n a few seconds to boot, then **from another machine** hit port `5678`. If this returns `200`, so can anyone on the internet:

```bash
curl -s -o /dev/null -w 'n8n on public IP -> HTTP %{http_code}\n' http://<PUBLIC_IP>:5678
```

Tear it straight back down - do not leave it running:

```bash
sudo docker compose -f insecure/docker-compose.yml down
```

### 4. Harden it (the "after")

```bash
# once, from an admin session - stores the encryption key + DB password in Secrets Manager:
AWS_REGION=us-east-1 ./scripts/create-secrets.sh

# edit hardened/Caddyfile (your domain + admin IP), then bring up the hardened stack:
N8N_HOST=n8n.yourdomain.com ./scripts/load-secrets.sh
```

### 5. Prove it (from another machine)

```bash
./scripts/verify-hardening.sh <PUBLIC_IP> n8n.yourdomain.com
# PASS  port 5678 is closed to the internet
# PASS  https responds on 443
```

---

## 📊 Before vs After

Same n8n. Locked down. Every item verified live on a real instance:

| Item | ❌ Before (insecure) | ✅ After (hardened) |
|------|---------------------|--------------------|
| Port 5678 to the internet | **OPEN** (HTTP 200 from public IP) | **closed** (connection refused) |
| n8n version | `1.100.0` (CVE-affected) | `1.123.64` patched |
| Encryption key | none (derived default) | AWS Secrets Manager |
| DB password | plaintext | AWS Secrets Manager |
| IAM | broad | least-privilege role |
| Editor UI | public | IP-restricted + TLS (Caddy) |

---

## 🎬 Example: proving the exposure, then closing it

```
# BEFORE - the insecure stack is up
$ curl -s -o /dev/null -w 'n8n on public IP -> HTTP %{http_code}\n' http://<PUBLIC_IP>:5678
n8n on public IP -> HTTP 200          # reachable by ANYONE on the internet

# ...apply the 4 fixes, tear down the insecure stack...

# AFTER - hit 5678 from outside again
$ curl -s -m 8 -o /dev/null -w 'port 5678 -> HTTP %{http_code}\n' http://<PUBLIC_IP>:5678 \
    || echo 'port 5678 -> connection refused / timed out (GOOD)'
port 5678 -> connection refused / timed out (GOOD)

# verify the two secrets landed in Secrets Manager (read-only)
$ aws secretsmanager list-secrets --region us-east-1 \
    --query "SecretList[?starts_with(Name,'n8n/')].Name" --output text
n8n/encryption-key
n8n/postgres-password
```

---

## 📁 Project Structure

```
secure-n8n-on-aws/
├── README.md
├── SETUP.md                             # follow-along: build the box from zero (Docker + Compose)
├── HARDENING.md                         # the full checklist, with the WHY per item
├── LICENSE
├── insecure/
│   └── docker-compose.yml               # the "before" - insecure ON PURPOSE, do not deploy
├── hardened/
│   ├── docker-compose.yml               # the "after" - patched, no public 5678, Postgres + Caddy
│   ├── Caddyfile                        # TLS + IP-restricted editor, public /webhook/* only
│   └── .env.example                     # the env vars the hardened compose expects
├── iam/
│   └── n8n-instance-role-policy.json    # least-privilege: read only the two n8n secrets
├── scripts/
│   ├── create-secrets.sh                # store enc key + DB password in AWS Secrets Manager
│   ├── load-secrets.sh                  # load secrets from Secrets Manager, bring up hardened stack
│   └── verify-hardening.sh              # verify from outside (5678 closed, HTTPS up)
└── research/
    └── 01-DEEP-RESEARCH.md              # verified CVE facts + sources behind every claim
```

---

## 🔐 Least-Privilege IAM Policy

The EC2 instance role can read **only** the two n8n secrets - nothing else:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyN8nSecretsFromSecretsManager",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:n8n/encryption-key-*",
        "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:n8n/postgres-password-*"
      ]
    }
  ]
}
```

> 💡 Replace `ACCOUNT_ID` with your account. The trailing `-*` matches the random suffix Secrets Manager appends to secret ARNs.

---

## 🐞 The CVE this fixes (CVE-2026-65589)

- **Type:** Information Disclosure (CWE-532 - sensitive data written to records).
- **Affected:** n8n **< 1.123.64**. Fixed in **1.123.64**.
- **What:** credentials passed as **custom HTTP headers in LLM sub-nodes** were written into workflow **execution records in plaintext**. Any authenticated user who could view or export executions could harvest them.
- **Severity:** CVSS 5.1 (MEDIUM). Not known-exploited, no public PoC.
- **Fix:** upgrade to `>= 1.123.64`, rotate any key passed via a custom header, purge old execution records, and use n8n's built-in credential objects instead of custom headers.
- **Source:** n8n advisory [GHSA-89gh-3pgc-v5h2](https://github.com/n8n-io/n8n/security/advisories/GHSA-89gh-3pgc-v5h2). Full verified facts + sources: [`research/01-DEEP-RESEARCH.md`](research/01-DEEP-RESEARCH.md).

---

## ✅ Hardening Checklist

The full checklist (with the WHY for each item) is in [`HARDENING.md`](HARDENING.md). The short version:

1. **Patch first** - n8n `>= 1.123.64`.
2. **AWS network** - Security Group allows only 22 (your IP), 80, 443; never 5678; private subnet where possible.
3. **Server / OS** - SSH keys only, no root/password login, unattended security updates.
4. **n8n config** - real `N8N_ENCRYPTION_KEY`, disable public signup, `WEBHOOK_URL=https://...`, session timeout, prune executions, telemetry off.
5. **Reverse proxy + TLS (Caddy)** - no published n8n ports; TLS at Caddy; editor IP-restricted; only `/webhook/*` public.
6. **Secrets (AWS-native)** - encryption key + DB password in Secrets Manager; least-privilege IAM role reads only those two.
7. **Credentials in n8n** - use built-in credential objects (not custom LLM headers); prefer OAuth; rotate.
8. **Monitoring** - review Executions, external uptime check, rotate/centralize logs.

---

## ⚙️ Customization

| What | Where |
|------|-------|
| Change the n8n version | `hardened/docker-compose.yml` → `image:` tag |
| Set your domain / admin IP | `hardened/Caddyfile` |
| Change the Secrets Manager region | `scripts/create-secrets.sh` / `load-secrets.sh` → `AWS_REGION` |
| Add more hardening env vars | `hardened/docker-compose.yml` → `environment:` |
| Scope the IAM policy to your account | `iam/n8n-instance-role-policy.json` → `ACCOUNT_ID` |

---

## 🐛 Troubleshooting

| Problem | Fix |
|---------|-----|
| `docker compose` not found | Install the Compose plugin - see [`SETUP.md`](SETUP.md) step 2 |
| `5678` still reachable after hardening | You didn't tear the insecure stack down: `docker compose -f insecure/docker-compose.yml down` |
| Caddy can't get a TLS cert | Your domain must resolve to the instance and ports 80/443 must be open in the Security Group |
| `create-secrets.sh` AccessDenied | Run it from an admin session (it needs `secretsmanager:CreateSecret` and `secretsmanager:PutSecretValue`) |
| n8n can't read its secrets | Attach the [least-privilege IAM role](#-least-privilege-iam-policy) to the instance |
| Webhooks fail from external services | They must hit `https://<your-domain>/webhook/...`; the editor is IP-restricted by design |

---

## 🔐 Security & Responsible Disclosure

The `insecure/` stack is **intentionally vulnerable** and exists only to demonstrate the problem. Never deploy it, and only ever use fake credentials (e.g. `sk-DEMO-...`) when reproducing the exposure.

Found a real security issue in this repo (not in the deliberately-insecure demo)? Please **do not open a public issue**. Instead, use GitHub's [private vulnerability reporting](https://github.com/simplynadaf/secure-n8n-on-aws/security/advisories/new) so it can be fixed before disclosure.

For vulnerabilities in n8n itself, report to the upstream project via the [n8n security advisories](https://github.com/n8n-io/n8n/security/advisories) page.

---

## ❓ FAQ

<details>
<summary><b>Do I need a domain name?</b></summary>

For real Let's Encrypt TLS, yes - Caddy needs a resolvable domain pointed at the instance. For a quick local test you can use Caddy's internal CA or a self-signed cert, but browsers will warn. Webhooks from external providers require a valid public HTTPS URL.
</details>

<details>
<summary><b>Why AWS Secrets Manager instead of a <code>.env</code> file?</b></summary>

A `.env` on disk is one `cat` away from leaking. Secrets Manager keeps the encryption key and DB password out of the repo and off the disk - `load-secrets.sh` injects them into the shell environment at runtime, and the instance reads them through a least-privilege IAM role with no static credentials. If you must use a `.env`, `chmod 600` it.
</details>

<details>
<summary><b>Is this production-ready?</b></summary>

It is a solid baseline that closes the common self-host mistakes (open 5678, unpatched image, plaintext secrets, public editor). For production, add the items in the Contributing list: infrastructure-as-code, webhook rate-limiting, secret rotation, and monitoring/alerting. Treat `HARDENING.md` as the checklist.
</details>

<details>
<summary><b>Will hardening break my existing webhooks?</b></summary>

No - `/webhook/*` and `/webhook-test/*` stay public through Caddy. Only the editor UI and REST API get IP-restricted. Make sure external services call `https://<your-domain>/webhook/...`, not the old `http://<ip>:5678` URL.
</details>

<details>
<summary><b>I lost my <code>N8N_ENCRYPTION_KEY</code>. Can I recover my credentials?</b></summary>

No. The key encrypts every stored credential; without it those credentials are unrecoverable and must be re-entered. Back the key up separately (e.g. a password manager) the moment you generate it.
</details>

---

## 🎬 Video Tutorial & Article

📺 **Video walkthrough:** _coming soon_
📝 **Full write-up:** _coming soon_

<!-- TODO: add the YouTube link (+ embedded thumbnail) and the Dev.to article URL once they are live. -->

This is **Episode 1** of the "n8n on AWS" series. Next up: run a real AI agent inside n8n with **Amazon Bedrock** - no OpenAI key.

---

## 🤝 Contributing

Contributions welcome! Ideas for improvement:

- Add a Terraform / CloudFormation module for the SG + IAM role + instance
- Add `fail2ban` / rate-limiting examples for the Caddy webhook paths
- Add an optional Cloudflare-in-front variant
- Add a GitHub Action that scans the compose files for regressions
- Automate secret rotation with Secrets Manager rotation lambdas

1. 🍴 Fork the repo
2. 🌿 Create a branch (`git checkout -b feature/terraform-module`)
3. 💾 Commit changes (`git commit -m 'Add Terraform module'`)
4. 🚀 Push (`git push origin feature/terraform-module`)
5. 📬 Open a Pull Request

---

## 📝 License

MIT - see the [LICENSE](LICENSE) file.

---

## ⭐ Star History

If this repo helped you lock down your n8n, a star helps others find it.

[![Star History Chart](https://api.star-history.com/svg?repos=simplynadaf/secure-n8n-on-aws&type=Date)](https://star-history.com/#simplynadaf/secure-n8n-on-aws&Date)

---

## 👨‍💻 Author

**Sarvar Nadaf** - Cloud Architect | AI Infrastructure & DevOps

[![LinkedIn](https://img.shields.io/badge/LinkedIn-sarvar04-blue?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/sarvar04/)
[![GitHub](https://img.shields.io/badge/GitHub-simplynadaf-black?style=flat-square&logo=github)](https://github.com/simplynadaf)
[![Dev.to](https://img.shields.io/badge/Dev.to-simplynadaf-0A0A0A?style=flat-square&logo=devdotto&logoColor=white)](https://dev.to/simplynadaf)

---

<div align="center">

**If this project helped you secure your n8n, consider giving it a ⭐**

*Built with ❤️ on AWS - n8n • Docker • Caddy • Secrets Manager*

</div>

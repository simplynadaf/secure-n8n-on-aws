# Setup - build the box from zero (follow-along)

These are the exact steps the video runs on camera, starting from a **fresh Amazon Linux
2023 EC2 instance** with nothing installed. They get you to the point where you can run
the insecure "before" stack, see the problem, and then move on to the hardened setup.

> Do this on a throwaway/scratch instance. The `insecure/` stack is intentionally
> exposed - never leave it running, and never point it at real credentials.

## 0. Prerequisites
- A fresh Amazon Linux 2023 EC2 instance (`ec2-user`).
- SSH access via your key.
- For the hardening steps: the AWS CLI (preinstalled on Amazon Linux) and either an
  admin session or an instance role that can call Secrets Manager (see `iam/`).

Confirm the starting point:
```bash
cat /etc/os-release | grep PRETTY_NAME
whoami
docker --version 2>&1 || echo 'docker: not installed yet'
```

## 1. Install Docker
```bash
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo systemctl is-active docker        # -> active
```

Optional (so you can run `docker` without `sudo` - log out/in after):
```bash
sudo usermod -aG docker ec2-user
```

## 2. Add the Docker Compose plugin
Amazon Linux's `docker` package does not include Compose v2, so install the plugin:
```bash
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -sSL \
  https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
sudo docker compose version           # -> Docker Compose version v2.29.7
```

## 3. Get this repo onto the box
```bash
git clone https://github.com/simplynadaf/secure-n8n-on-aws.git
cd secure-n8n-on-aws
```

## 4. (the "before") run the insecure stack - to SEE the problem, not to keep
```bash
cat insecure/docker-compose.yml       # note: published 5678, no encryption key, old image
sudo docker compose -f insecure/docker-compose.yml up -d
```
From another machine, prove it is open to the internet:
```bash
curl -s -o /dev/null -w 'n8n on public IP -> HTTP %{http_code}\n' http://<PUBLIC_IP>:5678
# HTTP 200 = anyone on the internet can reach the editor + API
```
Then tear it down before continuing:
```bash
sudo docker compose -f insecure/docker-compose.yml down
```

## 5. Now harden it
Continue with the hardened path:
1. `AWS_REGION=us-east-1 ./scripts/create-secrets.sh` - store the encryption key + DB
   password in AWS Secrets Manager (run once, from an admin session).
2. Edit `hardened/Caddyfile`: set your domain and your admin IP/CIDR.
3. `N8N_HOST=n8n.yourdomain.com ./scripts/load-secrets.sh` - pulls the secrets from
   Secrets Manager into the environment and brings up the hardened stack (n8n behind
   Caddy, no published 5678, Postgres with no plaintext password).
4. Attach the least-privilege role in `iam/n8n-instance-role-policy.json` to the instance
   so it can read only those two secrets.
5. From another machine: `./scripts/verify-hardening.sh <PUBLIC_IP> n8n.yourdomain.com`.

Work through `HARDENING.md` top to bottom - each item says WHY it matters.

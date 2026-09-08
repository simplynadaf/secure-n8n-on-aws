#!/usr/bin/env bash
# Create the two n8n secrets in AWS Secrets Manager (run once, from an admin session).
# The EC2 instance later reads them via its least-privilege instance role (see iam/).
# Nothing secret is ever written to the repo or a plaintext committed file.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"

echo "Generating a strong n8n encryption key and Postgres password..."
ENC_KEY="$(openssl rand -hex 32)"
PG_PASS="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"

echo "Storing n8n/encryption-key in Secrets Manager ($REGION)..."
aws secretsmanager create-secret \
  --name "n8n/encryption-key" \
  --secret-string "$ENC_KEY" \
  --region "$REGION" >/dev/null 2>&1 || \
aws secretsmanager put-secret-value \
  --secret-id "n8n/encryption-key" \
  --secret-string "$ENC_KEY" \
  --region "$REGION" >/dev/null

echo "Storing n8n/postgres-password in Secrets Manager ($REGION)..."
aws secretsmanager create-secret \
  --name "n8n/postgres-password" \
  --secret-string "$PG_PASS" \
  --region "$REGION" >/dev/null 2>&1 || \
aws secretsmanager put-secret-value \
  --secret-id "n8n/postgres-password" \
  --secret-string "$PG_PASS" \
  --region "$REGION" >/dev/null

echo "Done. Secrets stored. BACK UP the encryption key separately -"
echo "losing it means losing access to every credential n8n has stored."

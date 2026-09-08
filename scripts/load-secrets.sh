#!/usr/bin/env bash
# Load n8n secrets from AWS Secrets Manager into the environment, then bring up the
# hardened stack. Run this on the EC2 instance (which has the least-privilege role in
# iam/). Secrets live in the shell env only - never written to a committed file.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
export N8N_HOST="${N8N_HOST:-n8n.example.com}"

echo "Fetching secrets from AWS Secrets Manager ($REGION)..."
export N8N_ENCRYPTION_KEY="$(aws secretsmanager get-secret-value \
  --secret-id n8n/encryption-key --query SecretString --output text --region "$REGION")"
export POSTGRES_PASSWORD="$(aws secretsmanager get-secret-value \
  --secret-id n8n/postgres-password --query SecretString --output text --region "$REGION")"

echo "Secrets loaded into environment (not written to disk). Starting hardened stack..."
cd "$(dirname "$0")/../hardened"
docker compose up -d
echo "Up. Verify from OUTSIDE that 5678 is NOT reachable:"
echo "  curl -v http://<PUBLIC_IP>:5678   # must time out / connection refused"

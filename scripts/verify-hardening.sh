#!/usr/bin/env bash
# Verify the hardening from OUTSIDE the instance. Pass the instance public IP + domain.
# Usage: ./verify-hardening.sh <PUBLIC_IP> <DOMAIN>
set -uo pipefail

IP="${1:?usage: verify-hardening.sh <PUBLIC_IP> <DOMAIN>}"
DOMAIN="${2:?usage: verify-hardening.sh <PUBLIC_IP> <DOMAIN>}"
pass=0; fail=0
check() { if eval "$2"; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }

echo "Verifying n8n hardening on $IP / $DOMAIN ..."
# 1. Port 5678 must NOT be reachable from the internet.
check "port 5678 is closed to the internet" \
  "! timeout 5 bash -c '</dev/tcp/$IP/5678' 2>/dev/null"
# 2. HTTPS editor should answer on 443 (through Caddy).
check "https responds on 443" \
  "curl -ksS -o /dev/null -w '%{http_code}' https://$DOMAIN/ --max-time 10 | grep -qE '200|401|403'"
# 3. Plain http on the raw IP should not serve the n8n UI directly.
check "raw http on IP does not serve n8n directly" \
  "! curl -sS --max-time 5 http://$IP:5678/ | grep -qi n8n"

echo "----"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]

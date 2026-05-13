#!/bin/bash
set -e

# CLEAR STALE LOCKS (Prevents the crash loop you see in logs)
rm -f /tmp/gateway.log
rm -f ~/.openclaw/gateway.lock 2>/dev/null

# 1. Start the OpenClaw Gateway in the background
# We use a custom log path to avoid permission issues during E2E
echo "[entrypoint] Initializing OpenClaw Gateway..."
python3 -m openclaw.gateway --host 0.0.0.0 --port 18789 > /tmp/gateway.log 2>&1 &

# 2. Dynamic Port Wait (Better than 'sleep 5')
# This satisfies Quality Gates by not wasting time if the port opens fast
MAX_RETRIES=10
COUNT=0
while ! grep -q "WebSocket server running" /tmp/gateway.log && [ $COUNT -lt $MAX_RETRIES ]; do
  sleep 1
  ((COUNT++))
done

if grep -q "WebSocket server running" /tmp/gateway.log; then
    echo "✅ [entrypoint] WebSocket Gateway is ACTIVE on 18789"
else
    echo "⚠️ [entrypoint] Gateway startup delayed or failed. Logs:"
    cat /tmp/gateway.log
fi

# --- Persistent Secret Logic ---
generate_secret() {
  openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

SECRETS_FILE="/app/.data/.generated-secrets"
mkdir -p /app/.data
touch "$SECRETS_FILE"
chmod 600 "$SECRETS_FILE"

# Load & Export Secrets
set -a
[ -f "$SECRETS_FILE" ] && . "$SECRETS_FILE"
set +a

# Generate missing keys
if [ -z "$AUTH_SECRET" ]; then
  AUTH_SECRET=$(generate_secret)
  echo "AUTH_SECRET=$AUTH_SECRET" >> "$SECRETS_FILE"
  export AUTH_SECRET
fi

if [ -z "$API_KEY" ]; then
  API_KEY=$(generate_secret)
  echo "API_KEY=$API_KEY" >> "$SECRETS_FILE"
  export API_KEY
fi

echo "[entrypoint] Launching Mission Control UI..."
exec node server.js

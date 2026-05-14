#!/bin/bash
set -e

# 1. Initialize Persistent Directories (The 'Hippocampus')
mkdir -p /data/.hermes/memory
mkdir -p /data/.hermes/skills
mkdir -p /app/.data

# 2. Link Secrets (Ensures your sk_live_973fc748... survives restarts)
if [ -f "/data/.hermes/.env" ]; then
    ln -sf /data/.hermes/.env /app/.env
    echo "✅ [entrypoint] Secrets linked to persistent volume"
fi

# 3. Clean up crash locks
rm -f /tmp/gateway.log ~/.openclaw/gateway.lock 2>/dev/null

# 4. Start HUD Keep-Alive Loop (Fixes the 502 Bad Gateway)
if [ -d "/app/hermes-hudui" ]; then
    echo "🚀 [entrypoint] Starting Hermes HUD on Port 3005..."
    cd /app/hermes-hudui && source venv/bin/activate
    nohup sh -c "while true; do hermes-hudui --host 0.0.0.0 --port 3005; sleep 5; done" > /data/hud_backend.log 2>&1 &
    cd /app
fi

# 5. Launch Gateway with Persistence Enabled
echo "⚡ [entrypoint] Launching Hermes Gateway..."
python3 -m openclaw.gateway --host 0.0.0.0 --port 18789 --memory-path /data/.hermes/memory > /tmp/gateway.log 2>&1 &

# 6. Quality Gate: Wait for WebSocket stability
MAX_RETRIES=15
COUNT=0
while ! grep -q "WebSocket server running" /tmp/gateway.log && [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    COUNT=$((COUNT + 1))
done

# 7. Start UI
echo "✅ [entrypoint] Launching Mission Control UI..."
exec node server.js

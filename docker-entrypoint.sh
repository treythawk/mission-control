#!/bin/bash
set -e

# --- 1. PERSISTENCE ---
mkdir -p /data/.hermes/memory /data/.hermes/skills /app/.data
if [ -f "/data/.hermes/.env" ]; then
    ln -sf /data/.hermes/.env /app/.env
    echo "✅ [entrypoint] Secrets linked from volume"
fi

# --- 2. CLEANUP ---
rm -f /tmp/gateway.log ~/.openclaw/gateway.lock 2>/dev/null
pkill -9 -f "hermes-hudui" || true
pkill -9 -f "openclaw.gateway" || true

# --- 3. CORE: GATEWAY (:3009) ---
echo "⚡ [entrypoint] Launching Hermes Gateway on :3009..."
python3 -m openclaw.gateway --host 0.0.0.0 --port 3009 --memory-path /data/.hermes/memory > /tmp/gateway.log 2>&1 &

# --- 4. INTERFACE: HUD (:3008) ---
if [ -d "/app/hermes-hudui" ]; then
    echo "🚀 [entrypoint] Launching Hermes HUD on :3008..."
    cd /app/hermes-hudui && source venv/bin/activate
    nohup sh -c "while true; do hermes-hudui --host 0.0.0.0 --port 3008; sleep 5; done" > /data/hud_persistent.log 2>&1 &
    cd /app
fi

# --- 5. ORCHESTRATOR: MISSION CONTROL (:3000) ---
echo "⏳ [entrypoint] Waiting for Gateway stability..."
MAX_RETRIES=15; COUNT=0
while ! grep -q "WebSocket server running" /tmp/gateway.log && [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1; COUNT=$((COUNT + 1))
done

echo "✅ [entrypoint] Launching Mission Control UI on :$PORT..."
exec node server.js

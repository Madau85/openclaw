#!/bin/sh
set -eu

mkdir -p /data/.openclaw /data/workspace
chown -R node:node /data

OPENCLAW_RUNTIME_NPM_DIR="${OPENCLAW_RUNTIME_NPM_DIR:-/data/.openclaw/npm}"
mkdir -p "$OPENCLAW_RUNTIME_NPM_DIR"
chown -R node:node "$OPENCLAW_RUNTIME_NPM_DIR"

if [ ! -d "$OPENCLAW_RUNTIME_NPM_DIR/node_modules/openclaw" ] || \
  [ ! -d "$OPENCLAW_RUNTIME_NPM_DIR/node_modules/@openclaw/codex" ] || \
  ! su node -c "cd \"$OPENCLAW_RUNTIME_NPM_DIR\" && node -e \"import('openclaw/plugin-sdk/plugin-entry')\"" >/dev/null 2>&1; then
  echo "Repairing OpenClaw runtime npm cache in $OPENCLAW_RUNTIME_NPM_DIR..." >&2
  su node -c "cd \"$OPENCLAW_RUNTIME_NPM_DIR\" && npm install --omit=dev --no-audit --no-fund openclaw@latest @openclaw/codex@latest"
fi

# gog (Google Workspace CLI): make it reliably discoverable on PATH and point it at
# the persistent config/keyring on /data. Keyring password comes from the Railway
# variable GOG_KEYRING_PASSWORD (inherited), never hardcoded here.
if [ -x /data/.openclaw/tools/gog/gog ]; then
  cat > /usr/local/bin/gog <<'GOGEOF'
#!/bin/sh
export HOME=/data/workspace
export XDG_CONFIG_HOME=/data/workspace/.config
export GOG_KEYRING_BACKEND=file
exec /data/.openclaw/tools/gog/gog "$@"
GOGEOF
  chmod +x /usr/local/bin/gog
fi

if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  ORIGIN="https://${RAILWAY_PUBLIC_DOMAIN}"
  su node -c "node openclaw.mjs config set gateway.controlUi.allowedOrigins '[\"${ORIGIN}\"]' --strict-json"
fi

exec su node -c "tini -s -- node openclaw.mjs gateway --allow-unconfigured --bind lan --port ${PORT:-18789}"

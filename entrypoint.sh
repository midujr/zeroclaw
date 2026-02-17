#!/bin/sh
set -e

echo "============================================="
echo "  ZeroClaw — Timeweb App Platform"
echo "============================================="
echo "[INFO] $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "[INFO] RUST_LOG=$RUST_LOG"
echo ""

# Директории
mkdir -p /zeroclaw-data/.zeroclaw /zeroclaw-data/workspace 2>/dev/null || true

# Проверка API ключа
if [ -z "$ZEROCLAW_API_KEY" ]; then
  echo "[WARN] ZEROCLAW_API_KEY не задан!"
  echo "       Задайте переменную в панели Timeweb."
  echo ""
fi

# Генерация config.toml
CONFIG="/zeroclaw-data/.zeroclaw/config.toml"

cat > "$CONFIG" <<EOF
api_key = "${ZEROCLAW_API_KEY:-}"
default_provider = "${ZEROCLAW_PROVIDER:-openrouter}"
default_model = "${ZEROCLAW_MODEL:-anthropic/claude-sonnet-4-20250514}"
default_temperature = ${ZEROCLAW_TEMPERATURE:-0.7}

[memory]
backend = "${ZEROCLAW_MEMORY_BACKEND:-sqlite}"
auto_save = true
embedding_provider = "noop"

[gateway]
require_pairing = ${ZEROCLAW_GATEWAY_REQUIRE_PAIRING:-false}
allow_public_bind = ${ZEROCLAW_GATEWAY_ALLOW_PUBLIC_BIND:-true}

[autonomy]
level = "supervised"
workspace_only = true
allowed_commands = ["ls", "cat", "grep", "echo"]

[runtime]
kind = "native"

[heartbeat]
enabled = false

[tunnel]
provider = "none"

[secrets]
encrypt = false

[browser]
enabled = false
EOF

# Telegram
if [ -n "$ZEROCLAW_TELEGRAM_TOKEN" ]; then
  echo "[INFO] Telegram channel enabled"
  cat >> "$CONFIG" <<EOF

[channels_config.telegram]
bot_token = "${ZEROCLAW_TELEGRAM_TOKEN}"
allowed_users = [${ZEROCLAW_TELEGRAM_ALLOWED:-"*"}]
EOF
fi

# Discord
if [ -n "$ZEROCLAW_DISCORD_TOKEN" ]; then
  echo "[INFO] Discord channel enabled"
  cat >> "$CONFIG" <<EOF

[channels_config.discord]
bot_token = "${ZEROCLAW_DISCORD_TOKEN}"
allowed_users = [${ZEROCLAW_DISCORD_ALLOWED:-"*"}]
EOF
fi

# Лог конфига (без секретов)
echo "[INFO] config.toml:"
echo "---------------------------------------------"
sed 's/api_key = ".*"/api_key = "***"/; s/bot_token = ".*"/bot_token = "***"/' "$CONFIG"
echo "---------------------------------------------"
echo ""

# Проверка бинарника
if zeroclaw --help > /dev/null 2>&1; then
  echo "[OK] zeroclaw binary works"
else
  echo "[ERROR] zeroclaw binary failed!"
  exit 1
fi

# Запуск
COMMAND="${1:-gateway}"
shift 2>/dev/null || true

case "$COMMAND" in
  gateway)
    PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
    echo "[INFO] Starting gateway on [::]:${PORT}"
    echo ""
    exec zeroclaw gateway --port "$PORT" --host "[::]" "$@"
    ;;
  status)
    exec zeroclaw status "$@"
    ;;
  *)
    exec zeroclaw "$COMMAND" "$@"
    ;;
esac

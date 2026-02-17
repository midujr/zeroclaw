#!/bin/sh
set -e

echo "============================================="
echo "  ZeroClaw — Timeweb App Platform"
echo "============================================="
echo "[INFO] $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

mkdir -p /zeroclaw-data/.zeroclaw /zeroclaw-data/workspace 2>/dev/null || true
export HOME=/zeroclaw-data

CONFIG="/zeroclaw-data/.zeroclaw/config.toml"

# ── Шаг 1: Генерируем конфиг через onboard ─────────────────────
echo "[INFO] Generating config via zeroclaw onboard..."

API_KEY="${ZEROCLAW_API_KEY:-sk-placeholder}"
PROVIDER="${ZEROCLAW_PROVIDER:-openrouter}"

zeroclaw onboard --api-key "$API_KEY" --provider "$PROVIDER" 2>&1 || true

if [ ! -f "$CONFIG" ]; then
  echo "[ERROR] onboard не создал config.toml!"
  find /zeroclaw-data -name "config.toml" 2>/dev/null
  exit 1
fi

echo "[OK] config.toml создан через onboard"

# ── Шаг 2: Патчим конфиг ───────────────────────────────────────

# API key
if [ -n "$ZEROCLAW_API_KEY" ]; then
  sed -i "s|^api_key = .*|api_key = \"$ZEROCLAW_API_KEY\"|" "$CONFIG"
fi

# Model
if [ -n "$ZEROCLAW_MODEL" ]; then
  sed -i "s|^default_model = .*|default_model = \"$ZEROCLAW_MODEL\"|" "$CONFIG"
fi

# Temperature
if [ -n "$ZEROCLAW_TEMPERATURE" ]; then
  sed -i "s|^default_temperature = .*|default_temperature = $ZEROCLAW_TEMPERATURE|" "$CONFIG"
fi

# Gateway: ОБЯЗАТЕЛЬНО патчим — onboard ставит require_pairing=true и host=127.0.0.1
PAIRING="${ZEROCLAW_GATEWAY_REQUIRE_PAIRING:-false}"
PUBLIC="${ZEROCLAW_GATEWAY_ALLOW_PUBLIC_BIND:-true}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"

sed -i "s|^require_pairing = .*|require_pairing = $PAIRING|" "$CONFIG"
sed -i "s|^allow_public_bind = .*|allow_public_bind = $PUBLIC|" "$CONFIG"
sed -i "s|^port = .*|port = $PORT|" "$CONFIG"
sed -i "s|^host = .*|host = \"0.0.0.0\"|" "$CONFIG"

# Memory backend
if [ -n "$ZEROCLAW_MEMORY_BACKEND" ]; then
  sed -i "s|^backend = .*|backend = \"$ZEROCLAW_MEMORY_BACKEND\"|" "$CONFIG"
fi

# ── Шаг 3: Добавляем каналы ────────────────────────────────────

# Telegram
if [ -n "$ZEROCLAW_TELEGRAM_TOKEN" ]; then
  echo "[INFO] Adding Telegram channel..."
  TG_ALLOWED="${ZEROCLAW_TELEGRAM_ALLOWED:-*}"
  if [ "$TG_ALLOWED" = "*" ]; then
    TG_USERS='["*"]'
  else
    TG_USERS=$(echo "$TG_ALLOWED" | sed 's/[[:space:]]*,[[:space:]]*/","/g; s/^/["/; s/$/"]/')
  fi
  # Удаляем старую секцию если есть, добавляем новую
  sed -i '/\[channels_config\.telegram\]/,/^$/d' "$CONFIG"
  printf '\n[channels_config.telegram]\nbot_token = "%s"\nallowed_users = %s\n' \
    "$ZEROCLAW_TELEGRAM_TOKEN" "$TG_USERS" >> "$CONFIG"
fi

# Discord
if [ -n "$ZEROCLAW_DISCORD_TOKEN" ]; then
  echo "[INFO] Adding Discord channel..."
  DC_ALLOWED="${ZEROCLAW_DISCORD_ALLOWED:-*}"
  if [ "$DC_ALLOWED" = "*" ]; then
    DC_USERS='["*"]'
  else
    DC_USERS=$(echo "$DC_ALLOWED" | sed 's/[[:space:]]*,[[:space:]]*/","/g; s/^/["/; s/$/"]/')
  fi
  sed -i '/\[channels_config\.discord\]/,/^$/d' "$CONFIG"
  printf '\n[channels_config.discord]\nbot_token = "%s"\nallowed_users = %s\n' \
    "$ZEROCLAW_DISCORD_TOKEN" "$DC_USERS" >> "$CONFIG"
fi

# ── Шаг 4: Лог конфига ─────────────────────────────────────────
echo ""
echo "[INFO] Final config.toml:"
echo "---------------------------------------------"
sed 's/api_key = ".*"/api_key = "***"/; s/bot_token = ".*"/bot_token = "***"/' "$CONFIG"
echo "---------------------------------------------"
echo ""

# ── Шаг 5: Проверка и запуск ───────────────────────────────────
if zeroclaw --help > /dev/null 2>&1; then
  echo "[OK] zeroclaw binary works"
else
  echo "[ERROR] zeroclaw binary failed!"
  exit 1
fi

# Определяем режим запуска:
# - Если есть Telegram/Discord токен → daemon (включает каналы + gateway)
# - Иначе → gateway only
COMMAND="${1:-auto}"
shift 2>/dev/null || true

if [ "$COMMAND" = "auto" ]; then
  if [ -n "$ZEROCLAW_TELEGRAM_TOKEN" ] || [ -n "$ZEROCLAW_DISCORD_TOKEN" ]; then
    COMMAND="daemon"
  else
    COMMAND="gateway"
  fi
fi

case "$COMMAND" in
  daemon)
    echo "[INFO] Starting ZeroClaw DAEMON (gateway + channels)"
    echo "[INFO] Gateway: 0.0.0.0:${PORT}"
    echo "[INFO] Telegram: $([ -n "$ZEROCLAW_TELEGRAM_TOKEN" ] && echo 'ENABLED' || echo 'disabled')"
    echo "[INFO] Discord: $([ -n "$ZEROCLAW_DISCORD_TOKEN" ] && echo 'ENABLED' || echo 'disabled')"
    echo ""
    exec zeroclaw daemon "$@"
    ;;
  gateway)
    echo "[INFO] Starting ZeroClaw GATEWAY only (no channels)"
    echo "[INFO] Gateway: 0.0.0.0:${PORT}"
    echo ""
    exec zeroclaw gateway --port "$PORT" --host "0.0.0.0" "$@"
    ;;
  status)
    exec zeroclaw status "$@"
    ;;
  *)
    exec zeroclaw "$COMMAND" "$@"
    ;;
esac
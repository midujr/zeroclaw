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

# Gateway — полностью перезаписываем секцию [gateway]
PAIRING="${ZEROCLAW_GATEWAY_REQUIRE_PAIRING:-false}"
PUBLIC="${ZEROCLAW_GATEWAY_ALLOW_PUBLIC_BIND:-true}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"

# Удаляем старую секцию [gateway] и всё до следующей секции
sed -i '/^\[gateway\]/,/^\[/{/^\[gateway\]/d;/^\[/!d}' "$CONFIG"

# Вставляем новую секцию [gateway] перед [autonomy] или в конец
if grep -q '^\[autonomy\]' "$CONFIG"; then
  sed -i "/^\[autonomy\]/i\\
[gateway]\\
host = \"0.0.0.0\"\\
port = ${PORT}\\
require_pairing = ${PAIRING}\\
allow_public_bind = ${PUBLIC}\\
" "$CONFIG"
else
  cat >> "$CONFIG" <<EOF

[gateway]
host = "0.0.0.0"
port = ${PORT}
require_pairing = ${PAIRING}
allow_public_bind = ${PUBLIC}
EOF
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

# ── Шаг 5: Проверка бинарника ──────────────────────────────────
if zeroclaw --help > /dev/null 2>&1; then
  echo "[OK] zeroclaw binary works"
else
  echo "[ERROR] zeroclaw binary failed!"
  exit 1
fi

# ── Шаг 6: Определяем и запускаем режим ────────────────────────
COMMAND="${1:-auto}"
shift 2>/dev/null || true

if [ "$COMMAND" = "auto" ]; then
  if [ -n "$ZEROCLAW_TELEGRAM_TOKEN" ] || [ -n "$ZEROCLAW_DISCORD_TOKEN" ]; then
    COMMAND="daemon"
  else
    COMMAND="gateway"
  fi
fi

echo "[INFO] Mode: $COMMAND"
echo "[INFO] Telegram token set: $([ -n "$ZEROCLAW_TELEGRAM_TOKEN" ] && echo 'YES' || echo 'no')"
echo "[INFO] Discord token set: $([ -n "$ZEROCLAW_DISCORD_TOKEN" ] && echo 'YES' || echo 'no')"
echo ""

case "$COMMAND" in
  daemon)
    echo "[INFO] === Starting DAEMON (gateway + telegram + channels) ==="
    echo ""
    exec zeroclaw daemon "$@"
    ;;
  gateway)
    echo "[INFO] === Starting GATEWAY only ==="
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
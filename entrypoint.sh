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

# Gateway — перезаписываем через awk (надёжнее sed для многострочных секций)
PAIRING="${ZEROCLAW_GATEWAY_REQUIRE_PAIRING:-false}"
PUBLIC="${ZEROCLAW_GATEWAY_ALLOW_PUBLIC_BIND:-true}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"

awk -v port="$PORT" -v pairing="$PAIRING" -v public="$PUBLIC" '
  /^\[gateway\]/ {
    print "[gateway]"
    print "host = \"0.0.0.0\""
    print "port = " port
    print "require_pairing = " pairing
    print "allow_public_bind = " public
    skip=1
    next
  }
  /^\[/ && skip { skip=0 }
  !skip { print }
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

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
  # Удаляем старую секцию
  awk '/^\[channels_config\.telegram\]/{skip=1;next} /^\[/{skip=0} !skip{print}' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
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
  awk '/^\[channels_config\.discord\]/{skip=1;next} /^\[/{skip=0} !skip{print}' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
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

# ── Шаг 6: Запуск ──────────────────────────────────────────────
# ВСЕГДА авто-определяем режим, игнорируем CMD из Dockerfile
if [ -n "$ZEROCLAW_TELEGRAM_TOKEN" ] || [ -n "$ZEROCLAW_DISCORD_TOKEN" ]; then
  echo "[INFO] Mode: DAEMON (channels detected)"
  echo "[INFO] Telegram: $([ -n "$ZEROCLAW_TELEGRAM_TOKEN" ] && echo 'YES' || echo 'no')"
  echo "[INFO] Discord: $([ -n "$ZEROCLAW_DISCORD_TOKEN" ] && echo 'YES' || echo 'no')"
  echo ""
  echo "[INFO] === Starting DAEMON ==="
  exec zeroclaw daemon
else
  echo "[INFO] Mode: GATEWAY (no channels)"
  echo ""
  echo "[INFO] === Starting GATEWAY ==="
  exec zeroclaw gateway --port "$PORT" --host "0.0.0.0"
fi
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

cat > "$CONFIG" <<'ENDOFCONFIG'
api_key = "__API_KEY__"
default_provider = "__PROVIDER__"
default_model = "__MODEL__"
default_temperature = __TEMP__

[memory]
backend = "__MEMORY__"
auto_save = true
embedding_provider = "noop"

[gateway]
require_pairing = __PAIRING__
allow_public_bind = __PUBLIC__

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
ENDOFCONFIG

# Подставляем значения через sed
sed -i "s|__API_KEY__|${ZEROCLAW_API_KEY:-}|g" "$CONFIG"
sed -i "s|__PROVIDER__|${ZEROCLAW_PROVIDER:-openrouter}|g" "$CONFIG"
sed -i "s|__MODEL__|${ZEROCLAW_MODEL:-anthropic/claude-sonnet-4-20250514}|g" "$CONFIG"
sed -i "s|__TEMP__|${ZEROCLAW_TEMPERATURE:-0.7}|g" "$CONFIG"
sed -i "s|__MEMORY__|${ZEROCLAW_MEMORY_BACKEND:-sqlite}|g" "$CONFIG"
sed -i "s|__PAIRING__|${ZEROCLAW_GATEWAY_REQUIRE_PAIRING:-false}|g" "$CONFIG"
sed -i "s|__PUBLIC__|${ZEROCLAW_GATEWAY_ALLOW_PUBLIC_BIND:-true}|g" "$CONFIG"

# Telegram — кавычки вокруг каждого элемента в массиве
if [ -n "$ZEROCLAW_TELEGRAM_TOKEN" ]; then
  echo "[INFO] Telegram channel enabled"

  # Формируем allowed_users: если пусто или *, то ["*"]
  TG_ALLOWED="${ZEROCLAW_TELEGRAM_ALLOWED:-*}"
  if [ "$TG_ALLOWED" = "*" ]; then
    TG_USERS='["*"]'
  else
    # Оборачиваем каждый элемент в кавычки: user1,user2 → ["user1", "user2"]
    TG_USERS=$(echo "$TG_ALLOWED" | sed 's/[[:space:]]*,[[:space:]]*/","/g; s/^/["/; s/$/"]/')
  fi

  printf '\n[channels_config.telegram]\nbot_token = "%s"\nallowed_users = %s\n' \
    "$ZEROCLAW_TELEGRAM_TOKEN" "$TG_USERS" >> "$CONFIG"
fi

# Discord
if [ -n "$ZEROCLAW_DISCORD_TOKEN" ]; then
  echo "[INFO] Discord channel enabled"

  DC_ALLOWED="${ZEROCLAW_DISCORD_ALLOWED:-*}"
  if [ "$DC_ALLOWED" = "*" ]; then
    DC_USERS='["*"]'
  else
    DC_USERS=$(echo "$DC_ALLOWED" | sed 's/[[:space:]]*,[[:space:]]*/","/g; s/^/["/; s/$/"]/')
  fi

  printf '\n[channels_config.discord]\nbot_token = "%s"\nallowed_users = %s\n' \
    "$ZEROCLAW_DISCORD_TOKEN" "$DC_USERS" >> "$CONFIG"
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
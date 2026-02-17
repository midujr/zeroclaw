#!/bin/sh
set -e

CONFIG_DIR="$HOME/.zeroclaw"
CONFIG_FILE="$CONFIG_DIR/config.toml"

echo "============================================="
echo "  ZeroClaw — Timeweb App Platform Startup"
echo "============================================="
echo ""
echo "[INFO] Время запуска: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "[INFO] HOME=$HOME"
echo "[INFO] CONFIG_FILE=$CONFIG_FILE"
echo "[INFO] WORKSPACE=$ZEROCLAW_WORKSPACE"
echo "[INFO] RUST_LOG=$RUST_LOG"
echo ""

# ── Проверка API ключа ─────────────────────────────────────────
if [ -z "$ZEROCLAW_API_KEY" ]; then
    echo "============================================="
    echo "[ERROR] ZEROCLAW_API_KEY не задан!"
    echo ""
    echo "  Укажите переменную окружения в панели Timeweb:"
    echo "    ZEROCLAW_API_KEY=sk-ваш-ключ"
    echo ""
    echo "  Поддерживаемые провайдеры:"
    echo "    openrouter, openai, anthropic, ollama,"
    echo "    groq, mistral, deepseek, together, и др."
    echo "============================================="
    echo ""
    echo "[WARN] Запускаю без API ключа — gateway стартует,"
    echo "       но запросы к AI не будут работать."
    echo ""
fi

# ── Генерация config.toml ──────────────────────────────────────
mkdir -p "$CONFIG_DIR"
mkdir -p "$ZEROCLAW_WORKSPACE"

echo "[INFO] Генерация config.toml..."

cat > "$CONFIG_FILE" << TOML
# Автоматически сгенерировано entrypoint.sh
# Для Timeweb App Platform

api_key = "${ZEROCLAW_API_KEY:-}"
default_provider = "${ZEROCLAW_PROVIDER:-openrouter}"
default_model = "${ZEROCLAW_MODEL:-anthropic/claude-sonnet-4-20250514}"
default_temperature = ${ZEROCLAW_TEMPERATURE:-0.7}

[memory]
backend = "${ZEROCLAW_MEMORY_BACKEND:-sqlite}"
auto_save = true
embedding_provider = "noop"
vector_weight = 0.7
keyword_weight = 0.3

[gateway]
require_pairing = ${ZEROCLAW_GATEWAY_REQUIRE_PAIRING:-false}
allow_public_bind = ${ZEROCLAW_GATEWAY_ALLOW_PUBLIC_BIND:-true}

[autonomy]
level = "supervised"
workspace_only = true
allowed_commands = ["ls", "cat", "grep", "echo"]
forbidden_paths = ["/etc", "/root", "/proc", "/sys"]

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
TOML

# ── Telegram (если задан токен) ─────────────────────────────────
if [ -n "$ZEROCLAW_TELEGRAM_TOKEN" ]; then
    echo "[INFO] Настраиваю Telegram канал..."
    cat >> "$CONFIG_FILE" << TOML

[channels_config.telegram]
bot_token = "${ZEROCLAW_TELEGRAM_TOKEN}"
allowed_users = [${ZEROCLAW_TELEGRAM_ALLOWED:-"*"}]
TOML
fi

# ── Discord (если задан токен) ──────────────────────────────────
if [ -n "$ZEROCLAW_DISCORD_TOKEN" ]; then
    echo "[INFO] Настраиваю Discord канал..."
    cat >> "$CONFIG_FILE" << TOML

[channels_config.discord]
bot_token = "${ZEROCLAW_DISCORD_TOKEN}"
allowed_users = [${ZEROCLAW_DISCORD_ALLOWED:-"*"}]
TOML
fi

echo "[INFO] config.toml сгенерирован:"
echo "---------------------------------------------"
# Показываем конфиг без API ключа
sed 's/api_key = ".*"/api_key = "***HIDDEN***"/' "$CONFIG_FILE" | \
sed 's/bot_token = ".*"/bot_token = "***HIDDEN***"/'
echo "---------------------------------------------"
echo ""

# ── Проверка бинарника ──────────────────────────────────────────
echo "[INFO] Проверка zeroclaw..."
zeroclaw --help > /dev/null 2>&1 && echo "[OK] Бинарник zeroclaw работает" || {
    echo "[ERROR] zeroclaw не найден или не работает!"
    exit 1
}

# ── Запуск ──────────────────────────────────────────────────────
COMMAND="${1:-gateway}"
shift 2>/dev/null || true

HOST="${ZEROCLAW_GATEWAY_HOST:-[::]}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"

case "$COMMAND" in
    gateway)
        echo ""
        echo "============================================="
        echo "[INFO] Запускаю ZeroClaw Gateway"
        echo "[INFO] Host: $HOST"
        echo "[INFO] Port: $PORT"
        echo "[INFO] Provider: ${ZEROCLAW_PROVIDER:-openrouter}"
        echo "[INFO] Model: ${ZEROCLAW_MODEL:-anthropic/claude-sonnet-4-20250514}"
        echo "============================================="
        echo ""
        exec zeroclaw gateway --port "$PORT" --host "$HOST" "$@"
        ;;
    daemon)
        echo "[INFO] Запускаю ZeroClaw Daemon..."
        exec zeroclaw daemon "$@"
        ;;
    status)
        exec zeroclaw status "$@"
        ;;
    *)
        echo "[INFO] Запускаю: zeroclaw $COMMAND $*"
        exec zeroclaw "$COMMAND" "$@"
        ;;
esac

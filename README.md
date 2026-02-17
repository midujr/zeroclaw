# zeroclaw-timeweb

Обёртка [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) с shell-поддержкой для деплоя на Timeweb App Platform.

Оригинальный образ — distroless (без shell), этот образ добавляет debian-slim + entrypoint скрипт.

---

## Структура репозитория

```
zeroclaw-timeweb/
├── Dockerfile              # Берёт бинарник из оригинала → debian-slim
├── entrypoint.sh           # Генерирует config.toml из ENV
├── docker-compose.yml      # Для Timeweb (отдельный репо или этот же)
├── .github/workflows/
│   └── build.yml           # Автосборка и пуш в GHCR
└── README.md
```

---

## Шаг 1. Создать GitHub PAT (Personal Access Token)

1. Иди на **https://github.com/settings/tokens?type=beta** (Fine-grained tokens)
2. Нажми **"Generate new token"**
3. Настройки:
   - **Token name:** `ghcr-zeroclaw`
   - **Expiration:** 90 days (или больше)
   - **Repository access:** → "Only select repositories" → выбери `zeroclaw-timeweb`
   - **Permissions:**
     - Repository: **Contents** → Read
     - Account: **Packages** → Read and Write ← самое важное
4. **Generate token** → **скопируй токен** (он показывается один раз!)

> Или используй классический токен: https://github.com/settings/tokens/new
> Scope: `write:packages`, `read:packages`

---

## Шаг 2. Создать репозиторий и запушить

```bash
# Создай репо zeroclaw-timeweb на GitHub (можно через UI)
# Потом:

mkdir zeroclaw-timeweb && cd zeroclaw-timeweb
git init
git remote add origin https://github.com/midujr/zeroclaw-timeweb.git

# Скопируй сюда файлы: Dockerfile, entrypoint.sh, docker-compose.yml,
# .github/workflows/build.yml, README.md

git add .
git commit -m "initial: zeroclaw wrapper for timeweb"
git branch -M main
git push -u origin main
```

GitHub Actions автоматически соберёт и запушит образ в `ghcr.io/midujr/zeroclaw-timeweb:latest`.

---

## Шаг 3 (альтернатива). Собрать и запушить вручную

Если не хочешь ждать Actions:

```bash
# Логин в GHCR
echo "ТВОЙ_PAT_ТОКЕН" | docker login ghcr.io -u midujr --password-stdin

# Сборка
docker build -t ghcr.io/midujr/zeroclaw-timeweb:latest .

# Пуш
docker push ghcr.io/midujr/zeroclaw-timeweb:latest
```

---

## Шаг 4. Сделать образ публичным

По умолчанию образы в GHCR приватные. Чтобы Timeweb мог его скачать:

1. Иди на https://github.com/midujr?tab=packages
2. Кликни на `zeroclaw-timeweb`
3. **Package settings** → **Change visibility** → **Public**

---

## Шаг 5. Деплой в Timeweb

Для Timeweb нужен **отдельный репозиторий** (или этот же), где в корне лежит только `docker-compose.yml`.

1. Timeweb → **App Platform** → **Docker Compose**
2. Подключи репозиторий с `docker-compose.yml`
3. Переменные окружения:

| Переменная | Обязательная | Пример |
|-----------|:---:|---------|
| `ZEROCLAW_API_KEY` | ✅ | `sk-or-v1-xxxx` |
| `ZEROCLAW_PROVIDER` | | `openrouter` |
| `ZEROCLAW_MODEL` | | `anthropic/claude-sonnet-4-20250514` |
| `ZEROCLAW_TELEGRAM_TOKEN` | | `123456:ABC-DEF...` |
| `RUST_LOG` | | `debug,zeroclaw=trace` |

4. Запусти деплой — должен подняться за ~30 секунд (образ уже собран)

---

## Проверка

```bash
curl https://ваш-домен.tw1.ru/health
```

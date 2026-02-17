# Dockerfile
# Берём бинарник из оригинального образа и кладём в debian-slim
# (distroless не имеет shell, а Timeweb нуждается в entrypoint со скриптом)

FROM ghcr.io/theonlyhennygod/zeroclaw:latest AS source

FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tini \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Копируем бинарник из оригинального образа
COPY --from=source /usr/local/bin/zeroclaw /usr/local/bin/zeroclaw

# Копируем данные если есть
COPY --from=source /zeroclaw-data /zeroclaw-data

# Entrypoint скрипт
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV HOME=/zeroclaw-data
ENV ZEROCLAW_WORKSPACE=/zeroclaw-data/workspace
ENV ZEROCLAW_GATEWAY_PORT=3000
ENV RUST_LOG=info,zeroclaw=debug
ENV RUST_BACKTRACE=1

WORKDIR /zeroclaw-data
EXPOSE 3000

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
CMD ["gateway"]

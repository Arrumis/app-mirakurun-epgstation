ARG MIRAKURUN_BASE_IMAGE=chinachu/mirakurun
FROM node:24.22.1-bookworm-slim@sha256:55fb5f5a527ea2c5c4a95f963e48ef90aa38c7b346054fdc8ee9957a2b55d205 AS node-runtime
FROM ${MIRAKURUN_BASE_IMAGE}

# 上流イメージの更新時期に依存せず、修正版のNode.jsで実行する。
COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
RUN test "$(node --version)" = "v24.22.1"

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/bin:${PATH}"

USER root

COPY bin/recpt1-b25 /usr/local/bin/recpt1-b25

# PX-W3U4 / px4_drv は DVB ではなく chardev の /dev/px4video* を使うため、
# Mirakurun コンテナ内に recpt1 を追加する。
RUN set -eux; \
    build_deps="build-essential autoconf automake libtool git pkg-config"; \
    runtime_deps="ca-certificates pcscd libpcsclite1 libccid pcsc-tools"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ${build_deps} ${runtime_deps}; \
    npm install -g arib-b25-stream-test@0.2.9; \
    mkdir -p /opt/bin; \
    chmod 0755 /usr/local/bin/recpt1-b25; \
    ln -sf /usr/local/bin/arib-b25-stream-test /opt/bin/arib-b25-stream-test; \
    git clone --depth=1 https://github.com/stz2012/recpt1.git /tmp/recpt1; \
    cd /tmp/recpt1/recpt1; \
    ./autogen.sh; \
    ./configure; \
    make -j"$(nproc)"; \
    make install; \
    apt-get purge -y --auto-remove ${build_deps}; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/recpt1

ARG MIRAKURUN_BASE_IMAGE=chinachu/mirakurun
FROM ${MIRAKURUN_BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/bin:${PATH}"

USER root

# PX-W3U4 / px4_drv は DVB ではなく chardev の /dev/px4video* を使うため、
# Mirakurun コンテナ内に recpt1 を追加する。
RUN set -eux; \
    build_deps="build-essential autoconf automake libtool git pkg-config"; \
    runtime_deps="ca-certificates pcscd libpcsclite1 libccid pcsc-tools"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ${build_deps} ${runtime_deps}; \
    git clone --depth=1 https://github.com/stz2012/recpt1.git /tmp/recpt1; \
    cd /tmp/recpt1/recpt1; \
    ./autogen.sh; \
    ./configure; \
    make -j"$(nproc)"; \
    make install; \
    apt-get purge -y --auto-remove ${build_deps}; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/recpt1

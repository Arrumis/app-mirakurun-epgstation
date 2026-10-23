FROM node:24.22.1-bookworm-slim@sha256:55fb5f5a527ea2c5c4a95f963e48ef90aa38c7b346054fdc8ee9957a2b55d205 AS node-runtime
# Node.js 24に正式対応するv3を固定し、実行環境には修正版を適用する。
FROM l3tnun/epgstation:debian@sha256:df228bf4856c2ac1b1c60109e56b7645734aca473c9f6be0d23e1cf3927fe594
COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
RUN test "$(node --version)" = "v24.22.1"

ENV DEV="make gcc git g++ automake curl wget autoconf build-essential libass-dev libfreetype-dev libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev pkg-config texinfo zlib1g-dev"
ENV FFMPEG_VERSION=7.0

RUN apt-get update && \
    apt-get -y install $DEV && \
    apt-get -y install nasm libx264-dev libmp3lame-dev libopus-dev libvpx-dev && \
    apt-get -y install libx265-dev libnuma-dev && \
    apt-get -y install libasound2t64 libass9 libvdpau1 libva-x11-2 libva-drm2 libxcb-shm0 libxcb-xfixes0 libxcb-shape0 libvorbisenc2 libtheora0 libsndio7.0 libxv1 libaribb24-dev && \
\
# FFmpegのビルド
    mkdir /tmp/ffmpeg_sources && \
    cd /tmp/ffmpeg_sources && \
    curl -fsSL https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 | tar -xj --strip-components=1 && \
    ./configure \
      --prefix=/usr/local \
      --disable-shared \
      --pkg-config-flags=--static \
      --enable-gpl \
      --enable-libass \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libtheora \
      --enable-libvorbis \
      --enable-libvpx \
      --enable-libx264 \
      --enable-libx265 \
      --enable-version3 \
      --enable-libaribb24 \
      --enable-nonfree \
      --disable-debug \
      --disable-doc \
    && \
    make -j4 && \
    make install && \
\
# 不要なパッケージを削除
    apt-get -y remove $DEV && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# 開発用SDLの削除で消える実行時ライブラリを戻し、起動を確認する。
RUN apt-get update && \
    apt-get install -y --no-install-recommends libsdl2-2.0-0 && \
    rm -rf /var/lib/apt/lists/* && \
    ffmpeg -version && ffprobe -version

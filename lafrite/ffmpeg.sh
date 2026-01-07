#!/usr/bin/env bash
set -euo pipefail
WORKDIR="${HOME}/services/jellyfin/build-jff"
# FFMPEG_VER="6.1.1"   # adjust if needed
FFMPEG_VER="7.1.3-1"   # adjust if needed
JFF_BIN="${WORKDIR}/jellyfin-ffmpeg"

sudo apt update
sudo apt install -y build-essential git pkg-config yasm nasm libtool autoconf automake \
  libv4l-dev libdrm-dev libx264-dev libx265-dev libnuma-dev libvpx-dev libfdk-aac-dev \
  libmp3lame-dev libopus-dev libssl-dev libbz2-dev liblzma-dev libzstd-dev libaom-dev \
  libdav1d-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev libzvbi-dev

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Get FFmpeg source
if [ ! -d ffmpeg ]; then
  git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi
cd ffmpeg

# configure with v4l2 mem2mem and common codecs
PKG_CONFIG_PATH="" ./configure \
  --prefix="$WORKDIR/ffbuild" \
  --enable-gpl --enable-nonfree \
  --enable-libx264 --enable-libx265 --enable-libvpx --enable-libfdk-aac \
  --enable-libmp3lame --enable-libopus --enable-libdav1d --enable-libaom \
  --enable-libzvbi --enable-libv4l2 --enable-libdrm \
  --enable-shared --disable-debug --enable-small

make -j"$(nproc)"
make install

# Create a wrapper binary named jellyfin-ffmpeg that calls the built ffmpeg
mkdir -p "$WORKDIR/bin"
cat > "$JFF_BIN" <<'EOF'
#!/usr/bin/env bash
DIR="$(dirname "$(readlink -f "$0")")/../ffbuild/bin"
exec "$DIR/ffmpeg" "$@"
EOF
chmod +x "$JFF_BIN"

echo "Build complete. Copy $JFF_BIN to your La Frite at /usr/local/bin/jellyfin-ffmpeg"
echo "You can scp it: scp $JFF_BIN juca@lafrite:/usr/local/bin/jellyfin-ffmpeg"

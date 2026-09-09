#!/usr/bin/env bash
set -euo pipefail

# Paths and names (edit as needed)
CONFIG_DIR="${HOME}/services/jellyfin/config"
CACHE_DIR="${HOME}/services/jellyfin/cache"
MEDIA_DIR="${HOME}/services/jellyfin/media"
FFMPEG_HOST_BIN="/usr/local/bin/jellyfin-ffmpeg"
SYSTEM_FFMPEG="/usr/bin/ffmpeg"
COMPOSE_FILE="${PWD}/docker-compose.yml"
DOCKERFILE="${PWD}/Dockerfile.jellyfin-ffmpeg"

# 1) Basic checks
echo "Checking /dev/video0..."
if [ ! -e /dev/video0 ]; then
  echo "ERROR: /dev/video0 not found. Ensure kernel V4L2 driver is loaded." >&2
  exit 1
fi

echo "Checking docker and docker-compose..."
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not installed" >&2
  exit 1
fi
if ! command -v docker-compose >/dev/null 2>&1 && ! command -v docker compose >/dev/null 2>&1; then
  echo "ERROR: docker-compose or docker compose plugin not installed" >&2
  exit 1
fi

# 2) Create directories
mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${MEDIA_DIR}"
echo "Created config/cache/media dirs under ${HOME}/services/jellyfin"

# 3) Prepare jellyfin-ffmpeg binary on host
if [ -x "${FFMPEG_HOST_BIN}" ]; then
  echo "Using existing ${FFMPEG_HOST_BIN}"
else
  if [ -x "${SYSTEM_FFMPEG}" ]; then
    echo "Copying system ffmpeg to ${FFMPEG_HOST_BIN}"
    sudo cp "${SYSTEM_FFMPEG}" "${FFMPEG_HOST_BIN}"
    sudo chmod +x "${FFMPEG_HOST_BIN}"
  else
    echo "No system ffmpeg found at ${SYSTEM_FFMPEG}. You must build or place a jellyfin-ffmpeg binary at ${FFMPEG_HOST_BIN}" >&2
    exit 1
  fi
fi

# 4) Create docker-compose.yml
cat > "${COMPOSE_FILE}" <<'YML'
version: "3.8"
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    network_mode: host
    devices:
      - /dev/video0:/dev/video0
    group_add:
      - video
    volumes:
      - ./jellyfin/config:/config
      - ./jellyfin/cache:/cache
      - ./jellyfin/media:/media:ro
      - /usr/local/bin/jellyfin-ffmpeg:/usr/lib/jellyfin-ffmpeg/jellyfin-ffmpeg:ro
    restart: unless-stopped
YML

echo "Wrote ${COMPOSE_FILE}"

# 5) Optional Dockerfile to bake binary into image (if you prefer)
cat > "${DOCKERFILE}" <<'DOCK'
# Optional: build a custom jellyfin image that includes the host jellyfin-ffmpeg binary
FROM jellyfin/jellyfin:latest
# Copy the jellyfin-ffmpeg binary into the image (build context must include jellyfin-ffmpeg)
COPY jellyfin-ffmpeg /usr/lib/jellyfin-ffmpeg/jellyfin-ffmpeg
RUN chmod +x /usr/lib/jellyfin-ffmpeg/jellyfin-ffmpeg
DOCK

echo "Wrote ${DOCKERFILE} (optional). To build: docker build -t jellyfin-custom -f Dockerfile.jellyfin-ffmpeg ."

# 6) Start the stack
echo "Starting Jellyfin with docker-compose..."
if command -v docker-compose >/dev/null 2>&1; then
  docker-compose up -d
else
  docker compose up -d
fi

echo "Done. Jellyfin should be running. Visit http://<lafrite-ip>:8096"
echo "If you used the optional Dockerfile approach, copy your jellyfin-ffmpeg into the build context and run:"
echo "  docker build -t jellyfin-custom -f Dockerfile.jellyfin-ffmpeg ."
echo "  then update docker-compose.yml image: jellyfin-custom and restart."

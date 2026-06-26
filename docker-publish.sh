#!/bin/bash
set -e

IMAGE_NAME="wa_gate"

# Ambil versi dari mix.exs
VERSION=$(grep -oP '(?<=version: ")[^"]+' mix.exs)
if [ -z "$VERSION" ]; then
  echo "ERROR: Gagal baca versi dari mix.exs"
  exit 1
fi

# Login dulu agar bisa baca username aktif
echo "[1/3] Login ke Docker Hub..."
docker login

# Ambil username dari Docker Hub config (hasil login)
DOCKER_HUB_USER=$(cat ~/.docker/config.json 2>/dev/null | grep -oP '(?<="https://index.docker.io/v1/": \{"auth": ")[^"]+' | base64 -d 2>/dev/null | cut -d: -f1)

# Fallback: minta input manual jika tidak bisa deteksi
if [ -z "$DOCKER_HUB_USER" ]; then
  read -rp "Masukkan Docker Hub username kamu [kurniawan026]: " DOCKER_HUB_USER
  DOCKER_HUB_USER="${DOCKER_HUB_USER:-kurniawan026}"
fi

FULL_IMAGE="${DOCKER_HUB_USER}/${IMAGE_NAME}"

echo ""
echo "======================================"
echo "  Build & Publish Docker Image"
echo "  Image  : ${FULL_IMAGE}"
echo "  Version: ${VERSION}"
echo "======================================"

# Build image
echo ""
echo "[2/3] Building image..."
docker build \
  --tag "${FULL_IMAGE}:${VERSION}" \
  --tag "${FULL_IMAGE}:latest" \
  .

echo ""
echo "[3/3] Push ke Docker Hub..."
docker push "${FULL_IMAGE}:${VERSION}"
docker push "${FULL_IMAGE}:latest"

echo ""
echo "======================================"
echo "  Selesai!"
echo "  ${FULL_IMAGE}:${VERSION}"
echo "  ${FULL_IMAGE}:latest"
echo "======================================"

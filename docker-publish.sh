#!/bin/bash
set -e

IMAGE_NAME="wa_gate"

# Ambil versi dari mix.exs
VERSION=$(grep -oP '(?<=version: ")[^"]+' mix.exs)
if [ -z "$VERSION" ]; then
  echo "ERROR: Gagal baca versi dari mix.exs"
  exit 1
fi

# Ambil username dari Docker Hub config (hasil login)
DOCKER_HUB_USER=kurniawan026

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

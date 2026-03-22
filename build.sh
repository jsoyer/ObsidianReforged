#!/usr/bin/env bash
# Build and push multi-arch Docker image for ObsidianReforged
# Prerequisites: docker buildx with binfmt support
#   docker run --rm --privileged tonistiigi/binfmt --install all
set -euo pipefail

VERSION=$(git describe --tags --always --dirty 2>/dev/null \
    || ([ -f VERSION ] && cat VERSION) \
    || echo "dev")
IMAGE="jsoyer/obsidian-reforged"

echo "Building $IMAGE:$VERSION ..."

docker buildx build \
    --sbom=true \
    --provenance=true \
    --platform 'linux/amd64,linux/amd64/v2,linux/amd64/v3,linux/arm64,linux/arm/v7,linux/riscv64,linux/s390x,linux/ppc64le' \
    --tag "$IMAGE:latest" \
    --tag "$IMAGE:$VERSION" \
    --push \
    -f Build.Dockerfile \
    .

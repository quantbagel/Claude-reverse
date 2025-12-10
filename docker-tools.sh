#!/bin/bash
# docker-tools.sh - Run tools inside Docker for cross-platform compilation
# Usage: ./docker-tools.sh <tool> [args...]
#
# This wraps the tools to run inside a Linux x86_64 Docker container.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="decomp-env"
CONTAINER_NAME="decomp-runner"

# Build image if it doesn't exist
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Building Docker image (first time only)..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Run command in container
# Mount the project directory
docker run --rm -it \
    --platform linux/amd64 \
    -v "$SCRIPT_DIR:/project" \
    -w /project \
    "$IMAGE_NAME" \
    "$@"

#!/bin/bash
# Main Script to build Spotify RPM using Podman or Docker

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
LOG_FILE="${SCRIPT_DIR}/build.log"

# CI mode: stream logs to stdout (auto-detect GitHub Actions or pass --ci)
CI_MODE="${CI:-false}"
if [[ "${1:-}" == "--ci" ]]; then
    CI_MODE="true"
fi

# Logging helper: tee to both log file and stdout in CI, only file otherwise
log_cmd() {
    if [[ "$CI_MODE" == "true" ]]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
    else
        "$@" >> "$LOG_FILE" 2>&1
    fi
}

# Detect container runtime (prefer podman, fallback to docker)
if command -v podman &> /dev/null; then
    CONTAINER_RT="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_RT="docker"
else
    echo -e "${RED}Error: Neither Podman nor Docker is installed${NC}"
    echo -e "${YELLOW}Install one of them:${NC}"
    echo -e "  ${BLUE}sudo dnf install podman${NC}"
    echo -e "  ${BLUE}sudo dnf install docker${NC}"
    exit 1
fi

echo -e "${BLUE}Using container runtime: ${CONTAINER_RT}${NC}"

# Verify the runtime is working
if ! $CONTAINER_RT info &> /dev/null; then
    echo -e "${RED}Error: ${CONTAINER_RT} is not working correctly${NC}"
    echo -e "${YELLOW}Verify your ${CONTAINER_RT} installation${NC}"
    exit 1
fi

# Image and container name
IMAGE_NAME="spotify-builder"
CONTAINER_NAME="spotify-build-$$"

# Function to show last lines of log on failure
show_log_tail() {
    echo -e "${YELLOW}--- Last 30 lines of build.log ---${NC}"
    tail -n 30 "$LOG_FILE" 2>/dev/null || true
    echo -e "${YELLOW}--- End of log ---${NC}"
}

# Function to cleanup
cleanup() {
    echo -e "${BLUE}Cleaning up...${NC}"
    local containers
    containers=$($CONTAINER_RT ps -a --format '{{.ID}} {{.Image}}' 2>/dev/null | grep "$IMAGE_NAME" | awk '{print $1}') || true
    if [ -n "$containers" ]; then
        echo "$containers" | xargs $CONTAINER_RT rm -f >> "$LOG_FILE" 2>&1 || true
    fi
    $CONTAINER_RT rmi -f "$IMAGE_NAME" >> "$LOG_FILE" 2>&1 || true
    echo -e "${GREEN}✓ Done${NC}"
}

# Function to build container image
build_image() {
    echo -e "${BLUE}Building image...${NC}"
    cd "$SCRIPT_DIR"
    if log_cmd $CONTAINER_RT build -t "$IMAGE_NAME" .; then
        echo -e "${GREEN}✓ Image built${NC}"
    else
        echo -e "${RED}✗ Image build failed${NC}"
        show_log_tail
        exit 1
    fi
}

# Function to build the RPM
build_rpm() {
    echo -e "${BLUE}Building RPM...${NC}"

    mkdir -p "$OUTPUT_DIR"

    if log_cmd $CONTAINER_RT run --rm \
        --name "$CONTAINER_NAME" \
        -v "$OUTPUT_DIR:/output:z" \
        "$IMAGE_NAME"; then

        # Verify RPM was created
        if ls "$OUTPUT_DIR"/*.rpm 1> /dev/null 2>&1; then
            echo -e "${GREEN}✓ Build successful${NC}"
            ls -lh "$OUTPUT_DIR"/*.rpm
        else
            echo -e "${RED}✗ RPM not found in output directory${NC}"
            show_log_tail
            exit 1
        fi
    else
        echo -e "${RED}✗ RPM build failed${NC}"
        show_log_tail
        exit 1
    fi
}

# Banner
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════╗
║   Spotify RPM Builder for Fedora          ║
║   Isolated build with Podman/Docker       ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Clean previous log
> "$LOG_FILE"

# Build image
build_image

# Build the RPM
build_rpm

# Cleanup container image
cleanup

echo -e "${GREEN}Process completed!${NC}"

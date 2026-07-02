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

# Options (parse args)
CI_MODE="${CI:-false}"
CLEAN_IMAGE=false
FEDORA_VERSION="${FEDORA_VERSION:-43}"
SPOTIFY_VERSION="${SPOTIFY_VERSION:-}"  # empty = latest

for arg in "$@"; do
    case "$arg" in
        --ci)    CI_MODE="true" ;;
        --clean) CLEAN_IMAGE=true ;;
        --help)
            echo "Usage: $0 [--ci] [--clean]"
            echo ""
            echo "  --ci      Stream build logs to stdout (auto-detected in GitHub Actions)"
            echo "  --clean   Remove the builder image after a successful build"
            echo ""
            echo "Environment variables:"
            echo "  FEDORA_VERSION   Fedora base image version (default: 43)"
            echo "  SPOTIFY_VERSION  Pin a specific Spotify version (default: latest)"
            exit 0
            ;;
    esac
done

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

# Function to cleanup containers (not the image — reuse it next time)
cleanup_containers() {
    local containers
    containers=$($CONTAINER_RT ps -a --format '{{.ID}} {{.Image}}' 2>/dev/null | grep "$IMAGE_NAME" | awk '{print $1}') || true
    if [ -n "$containers" ]; then
        echo "$containers" | xargs $CONTAINER_RT rm -f >> "$LOG_FILE" 2>&1 || true
    fi
}

# Function to remove the builder image (only when --clean is passed)
cleanup_image() {
    echo -e "${BLUE}Removing builder image...${NC}"
    $CONTAINER_RT rmi -f "$IMAGE_NAME" >> "$LOG_FILE" 2>&1 || true
    echo -e "${GREEN}✓ Image removed${NC}"
}

# Function to build container image (skip if already exists)
build_image() {
    if $CONTAINER_RT image inspect "$IMAGE_NAME" &> /dev/null; then
        echo -e "${GREEN}✓ Image already exists, skipping build (use --clean to force rebuild)${NC}"
        return
    fi

    echo -e "${BLUE}Building image (Fedora ${FEDORA_VERSION})...${NC}"
    cd "$SCRIPT_DIR"
    if log_cmd $CONTAINER_RT build \
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
        -t "$IMAGE_NAME" .; then
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

    local -a run_args=(
        --rm
        --name "$CONTAINER_NAME"
        -v "$OUTPUT_DIR:/output:z"
    )

    # Forward optional pinned version
    if [ -n "$SPOTIFY_VERSION" ]; then
        run_args+=(-e "SPOTIFY_VERSION=${SPOTIFY_VERSION}")
        echo -e "${BLUE}Pinned Spotify version: ${SPOTIFY_VERSION}${NC}"
    fi

    if log_cmd $CONTAINER_RT run "${run_args[@]}" "$IMAGE_NAME"; then

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

# Build image (cached if it already exists)
build_image

# Clean up any leftover containers from previous runs
cleanup_containers

# Build the RPM
build_rpm

# Remove the image only if --clean was requested
if [[ "$CLEAN_IMAGE" == "true" ]]; then
    cleanup_image
fi

echo -e "${GREEN}Process completed!${NC}"

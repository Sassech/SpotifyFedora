#!/bin/bash
# Main Script to build Spotify RPM using Podman

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"

# Image and container name
IMAGE_NAME="spotify-builder"
CONTAINER_NAME="spotify-build-$$"

# Function to cleanup
cleanup() {
    podman ps -a | grep "$IMAGE_NAME" | awk '{print $1}' | xargs podman rm -f 2>/dev/null || true
    podman rmi -f "$IMAGE_NAME" 2>/dev/null || true
}

# Function to build Podman image
build_image() {
    echo -e "${BLUE}Building image...${NC}"
    cd "$SCRIPT_DIR"
    podman build -t "$IMAGE_NAME" .
}

# Function to build the RPM
build_rpm() {
    echo -e "${BLUE}Building RPM...${NC}"
    
    mkdir -p "$OUTPUT_DIR"
    
    podman run --rm \
        --name "$CONTAINER_NAME" \
        -v "$OUTPUT_DIR:/output" \
        "$IMAGE_NAME"
    
    # Verify RPM was created
    if ls "$OUTPUT_DIR"/*.rpm 1> /dev/null 2>&1; then
        echo -e "${GREEN}Build successful!${NC}"
        ls -lh "$OUTPUT_DIR"/*.rpm
    else
        echo -e "${RED}Error: RPM was not generated${NC}"
        return 1
    fi
}

# Verify Podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: Podman is not installed${NC}"
    echo -e "${YELLOW}Install Podman with:${NC}"
    echo -e "  ${BLUE}sudo dnf install podman${NC}"
    exit 1
fi

# Verify Podman is working
if ! podman info &> /dev/null; then
    echo -e "${RED}Error: Podman is not working correctly${NC}"
    echo -e "${YELLOW}Verify Podman installation${NC}"
    exit 1
fi

# Banner
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════╗
║   Spotify RPM Builder for Fedora          ║
║   Isolated build with Podman              ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Build image
build_image

# Build the RPM
build_rpm

# Cleanup Podman image
cleanup

echo -e "${GREEN}Process completed!${NC}"


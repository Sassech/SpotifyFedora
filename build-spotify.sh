#!/bin/bash
set -euo pipefail

echo "=== Spotify RPM Builder ==="

# Spotify repository URL
SPOTIFY_REPO="http://repository.spotify.com/pool/non-free/s/spotify-client/"

# Get latest available version
echo "Fetching latest version from Spotify repository..."
LATEST_DEB=$(curl -sL --connect-timeout 15 --max-time 30 "$SPOTIFY_REPO" \
    | grep -oP 'href="\K[^"]*\.deb' | grep amd64 | sort -V | tail -n 1)

if [ -z "$LATEST_DEB" ]; then
    echo "Error: Could not determine latest version from $SPOTIFY_REPO"
    echo "Check your network connection or if the repository URL has changed."
    exit 1
fi

echo "Package: ${LATEST_DEB}"

# Download the .deb if it doesn't exist
if [ ! -f "/build/${LATEST_DEB}" ]; then
    echo "Downloading..."
    curl -L -f --retry 3 --connect-timeout 15 -o "/build/${LATEST_DEB}" "${SPOTIFY_REPO}${LATEST_DEB}"
fi

# Extract version from filename
VERSION=$(echo "$LATEST_DEB" | grep -oP '\d+\.\d+\.\d+\.\d+\.g[a-f0-9]+')

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from filename: $LATEST_DEB"
    exit 1
fi

echo "Version: ${VERSION}"

# Create directory structure for rpmbuild
BUILD_DIR="/root/rpmbuild"
mkdir -p "${BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Copy .deb to SOURCES
cp "/build/${LATEST_DEB}" "${BUILD_DIR}/SOURCES/"

# Create temporary working directory
WORK_DIR="/tmp/spotify-build"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Extract .deb manually
echo "Extracting .deb package..."
ar x "/build/${LATEST_DEB}" 2>/dev/null
tar xf data.tar.* 2>/dev/null

# Create installation directory
INSTALL_DIR="${BUILD_DIR}/BUILD/spotify-${VERSION}/BUILDROOT"
mkdir -p "${INSTALL_DIR}/usr/bin"
mkdir -p "${INSTALL_DIR}/usr/share/spotify"
mkdir -p "${INSTALL_DIR}/usr/share/applications"
mkdir -p "${INSTALL_DIR}/usr/share/icons/hicolor"
mkdir -p "${INSTALL_DIR}/usr/share/appdata"
mkdir -p "${INSTALL_DIR}/usr/share/man/man1"

# Copy Spotify files
cp -ar usr/share/spotify/* "${INSTALL_DIR}/usr/share/spotify/"

# Create launcher script
cat > "${INSTALL_DIR}/usr/bin/spotify" << 'LAUNCHER'
#!/usr/bin/bash
# Spotify launcher with Fedora fixes

# Disable hardware acceleration that causes black screen
export SPOTIFY_CLEAN_CACHE=1

# Flags to improve compatibility
exec /usr/share/spotify/spotify \
    --disable-gpu-sandbox \
    --disable-seccomp-filter-sandbox \
    --no-zygote \
    "$@"
LAUNCHER
chmod +x "${INSTALL_DIR}/usr/bin/spotify"

# Create .desktop file
cat > "${INSTALL_DIR}/usr/share/applications/spotify.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Spotify
GenericName=Music Player
Comment=Spotify streaming music client
Icon=spotify
Exec=spotify %U
Terminal=false
MimeType=x-scheme-handler/spotify;
Categories=Audio;Music;Player;AudioVideo;
StartupWMClass=spotify
DESKTOP

# Copy icons
for size in 16 22 24 32 48 64 128 256 512; do
    if [ -f "usr/share/spotify/icons/spotify-linux-${size}.png" ]; then
        mkdir -p "${INSTALL_DIR}/usr/share/icons/hicolor/${size}x${size}/apps"
        cp "usr/share/spotify/icons/spotify-linux-${size}.png" \
           "${INSTALL_DIR}/usr/share/icons/hicolor/${size}x${size}/apps/spotify.png"
    fi
done

# Create appdata.xml
cat > "${INSTALL_DIR}/usr/share/appdata/spotify.xml" << 'APPDATA'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop">
  <id>spotify.desktop</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>LicenseRef-proprietary</project_license>
  <name>Spotify</name>
  <summary>Online music streaming service</summary>
  <description>
    <p>Spotify is a digital music service that gives you access to millions of songs.</p>
  </description>
  <url type="homepage">https://www.spotify.com/</url>
</component>
APPDATA

# Create man page
cat > "${INSTALL_DIR}/usr/share/man/man1/spotify.1" << 'MANPAGE'
.TH SPOTIFY 1 "December 2025" "Spotify Client" "User Commands"
.SH NAME
spotify \- Spotify streaming music client
.SH SYNOPSIS
.B spotify
[\fIOPTIONS\fR]
.SH DESCRIPTION
Spotify is a digital music service that gives you access to millions of songs.
.SH OPTIONS
.TP
\fB\-\-help\fR
Show help options
.SH SEE ALSO
https://www.spotify.com/
MANPAGE

# Adjust library permissions
find "${INSTALL_DIR}/usr/share/spotify" -name '*.so*' -type f -exec chmod 755 {} \;

# Generate spec file
/build/create-spec.sh "${VERSION}" "${INSTALL_DIR}" "${BUILD_DIR}/SPECS/spotify.spec"

# Build the RPM (full output — do NOT suppress errors)
echo "Building RPM, this may take a while..."

rpmbuild -bb \
    --define "_topdir ${BUILD_DIR}" \
    "${BUILD_DIR}/SPECS/spotify.spec"

# Copy resulting RPM to output directory
mkdir -p /output
chmod 777 /output 2>/dev/null || true

if ls "${BUILD_DIR}/RPMS/x86_64/"*.rpm 1> /dev/null 2>&1; then
    cp "${BUILD_DIR}/RPMS/x86_64/"*.rpm /output/
    echo "Build completed successfully"
    ls -lh /output/*.rpm
else
    echo "Error: No RPM files found in ${BUILD_DIR}/RPMS/x86_64/"
    echo "rpmbuild may have failed silently. Check the output above."
    exit 1
fi

rm -rf "$BUILD_DIR" "$WORK_DIR" "/build/${LATEST_DEB}" 2>/dev/null || true

#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Spotify RPM Builder ===${NC}"

# Spotify repository URL
SPOTIFY_REPO="http://repository.spotify.com/pool/non-free/s/spotify-client/"

# Get latest available version
LATEST_DEB=$(curl -sL $SPOTIFY_REPO | grep -oP 'href="\K[^"]*\.deb' | grep amd64 | sort -V | tail -n 1)

if [ -z "$LATEST_DEB" ]; then
    echo -e "${RED}Error: Could not determine latest version${NC}"
    exit 1
fi

echo -e "${GREEN}Version: ${LATEST_DEB}${NC}"

# Download the .deb if it doesn't exist
if [ ! -f "/build/${LATEST_DEB}" ]; then
    echo -e "${YELLOW}Downloading...${NC}"
    wget -q --show-progress "${SPOTIFY_REPO}${LATEST_DEB}" -O "/build/${LATEST_DEB}"
fi

# Extract version from filename
VERSION=$(echo $LATEST_DEB | grep -oP '\d+\.\d+\.\d+\.\d+\.g[a-f0-9]+')

# Create directory structure for rpmbuild
BUILD_DIR="/root/rpmbuild"
mkdir -p ${BUILD_DIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Copy .deb to SOURCES
cp "/build/${LATEST_DEB}" ${BUILD_DIR}/SOURCES/

# Create temporary working directory
WORK_DIR="/tmp/spotify-build"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Extract .deb manually
echo -e "${YELLOW}Extracting...${NC}"
ar x "/build/${LATEST_DEB}"
tar xf data.tar.*

# Create installation directory
INSTALL_DIR="${BUILD_DIR}/BUILD/spotify-client-${VERSION}/BUILDROOT"
mkdir -p "${INSTALL_DIR}/usr/bin"
mkdir -p "${INSTALL_DIR}/usr/share/spotify-client"
mkdir -p "${INSTALL_DIR}/usr/share/applications"
mkdir -p "${INSTALL_DIR}/usr/share/icons/hicolor"
mkdir -p "${INSTALL_DIR}/usr/share/appdata"
mkdir -p "${INSTALL_DIR}/usr/share/man/man1"

# Copy Spotify files
cp -ar usr/share/spotify/* "${INSTALL_DIR}/usr/share/spotify-client/"

# Create launcher script
cat > "${INSTALL_DIR}/usr/bin/spotify" << 'LAUNCHER'
#!/usr/bin/bash
# Spotify launcher with Fedora fixes

# Disable hardware acceleration that causes black screen
export SPOTIFY_CLEAN_CACHE=1

# Flags to improve compatibility
exec /usr/share/spotify-client/spotify \
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

# Crear página del manual
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
find "${INSTALL_DIR}/usr/share/spotify-client" -name '*.so*' -type f -exec chmod 755 {} \;

# Create simplified spec file
cat > ${BUILD_DIR}/SPECS/spotify-client.spec << EOF
%global debug_package %{nil}
%global __strip /bin/true

Name:           spotify-client
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Spotify desktop client
License:        Proprietary
URL:            https://www.spotify.com/

Requires:       libatomic
Requires:       libayatana-appindicator-gtk3

%description
Spotify is a digital music service that gives you access to millions of songs.

%install
mkdir -p %{buildroot}
cp -a ${INSTALL_DIR}/* %{buildroot}/

%files
%{_bindir}/spotify
%{_datadir}/spotify-client/
%{_datadir}/applications/spotify.desktop
%{_datadir}/icons/hicolor/*/apps/spotify.png
%{_datadir}/appdata/spotify.xml
%{_mandir}/man1/spotify.1*

%changelog
* $(date "+%a %b %d %Y") Automated Build <builder@localhost> - ${VERSION}-1
- Automated build of Spotify client ${VERSION}
EOF

# Build the RPM
echo -e "${YELLOW}Building RPM...${NC}"

rpmbuild -bb \
    --define "_topdir ${BUILD_DIR}" \
    ${BUILD_DIR}/SPECS/spotify-client.spec

# Copy resulting RPM to output directory
mkdir -p /output
cp ${BUILD_DIR}/RPMS/x86_64/*.rpm /output/

echo -e "${GREEN}Build completed${NC}"
ls -lh /output/*.rpm

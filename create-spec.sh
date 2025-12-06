#!/bin/bash
# Generate Spotify RPM spec file

VERSION=$1
INSTALL_DIR=$2
SPEC_FILE=$3

if [ -z "$VERSION" ] || [ -z "$INSTALL_DIR" ] || [ -z "$SPEC_FILE" ]; then
    echo "Usage: $0 <version> <install_dir> <spec_file>"
    exit 1
fi

cat > "$SPEC_FILE" << EOF
%global debug_package %{nil}
%global __strip /bin/true

Name:           spotify
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

%post
chmod -R a+wr %{_datadir}/spotify/ || true

%files
%{_bindir}/spotify
%{_datadir}/spotify/
%{_datadir}/applications/spotify.desktop
%{_datadir}/icons/hicolor/*/apps/spotify.png
%{_datadir}/appdata/spotify.xml
%{_mandir}/man1/spotify.1*

%changelog
* $(date "+%a %b %d %Y") Automated Build <builder@localhost> - ${VERSION}-1
- Automated build of Spotify client ${VERSION}
EOF

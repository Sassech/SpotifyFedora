# Spotify RPM Builder for Fedora

Build Spotify RPM packages for Fedora using isolated containers.

## Download Prebuilt RPM

Get the latest release from [Releases](https://github.com/sassech/SpotifyFedora/releases).

## Build Locally

### Requirements
- Docker or Podman (`sudo dnf install podman`)
- ~500MB disk space

### Quick Start

```bash
./build.sh
sudo dnf install ./output/spotify-*.rpm
```

## Included Fixes

Custom launcher with Fedora compatibility flags:
- GPU sandbox disabled
- Seccomp filter sandbox disabled
- Clean cache flag

## Uninstall

```bash
sudo dnf remove spotify
```

## Build Info
- **Build Time**: ~2-5 min
- **RPM Size**: ~200MB
- **Arch**: x86_64

## Credits
- Based on [lpf-spotify-client](https://github.com/leamas/lpf) by leamas
- Containerization approach using Podman/Docker

Spotify is proprietary software owned by Spotify AB.

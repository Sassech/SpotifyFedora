# Spotify RPM Builder for Fedora

A cleaner alternative to **lpf-spotify-client** that builds Spotify RPM packages using Podman containers instead of polluting your system with build dependencies.

## Requirements

- Podman (preinstalled on Fedora)
- Fedora Linux (tested on Fedora 43)

## Usage

```bash
./build.sh
sudo dnf install ./output/spotify-*.rpm
```

## How It Works

1. Downloads official Spotify .deb from repository
2. Extracts and reorganizes files for Fedora standards
3. Creates custom launcher with GPU sandbox fixes
4. Builds RPM with desktop integration (icons, .desktop file, man page)
5. Cleans up container and temporary files

## Included Fixes (Under Testing)

Custom launcher that attempts to prevent common Fedora issues:

- GPU sandbox disabled (may help with black screen issues)
- Seccomp filter sandbox disabled
- Clean cache flag for better compatibility

**Note**: These fixes are still being tested. Black screen issues at startup still occur.

## Troubleshooting

If build fails, check `build.log` for errors. Common issues:

- Network connection required
- Insufficient disk space
- Podman not working: run `podman info`

## Credits

This project combines and adapts code from multiple sources:

- **Build process inspired by**: [lpf-spotify-client](https://github.com/leamas/lpf) by leamas
  - RPM packaging methodology
  - .deb extraction and conversion approach
- **Launcher fixes**: Community-sourced solutions for Fedora compatibility issues

  - GPU sandbox flags from various Fedora/Spotify bug reports
  - Wayland/X11 compatibility workarounds

- **Containerization approach**: Original implementation using Podman for isolated builds

## License

This project is a packaging script. Spotify is proprietary software owned by Spotify AB.

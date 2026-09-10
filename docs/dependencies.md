# Dependencies

The tested host is Arch-based CachyOS. Package names differ on other distributions.

## Runtime

- BlueZ: `bluez`, `bluez-utils`
- Rootless Podman
- Native QDomyos-Zwift (QZ)
- Upstream [netbrain/zwift](https://github.com/netbrain/zwift)
- An active user D-Bus session
- Optional diagnostics: `avahi` (`avahi-browse`), `iproute2`, `rfkill`
- Optional NVIDIA graphics: proprietary NVIDIA driver and `nvidia-container-toolkit`

## Build QZ on Arch/CachyOS

Install the build tools and repository packages:

```sh
sudo pacman -S --needed base-devel git bluez bluez-utils \
  qt5-base qt5-declarative qt5-location qt5-networkauth qt5-websockets \
  qt5-speech qt5-multimedia qt5-quickcontrols2 qt5-quickcontrols \
  qt5-graphicaleffects qt5-tools
```

QZ also required two packages unavailable in the configured repositories:

- `qt5-connectivity` (AUR)
- `qt5-charts` (AUR)

AUR content is user-produced. Review each PKGBUILD and its sources, build as a normal user, and install only the resulting package with pacman. Do not run an AUR helper or `makepkg` as root.

Clone QZ with submodules, apply the patch in `patches/`, and build the application project as described in [QZ installation notes](qz-installed.md). Install netbrain/zwift using its upstream instructions and set `NETWORKING="host"`; this repository does not redistribute either upstream project or Zwift.

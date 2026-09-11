# Dependencies and installer details

Start with the [README](../README.md#1-install). `install.sh` automates package installation and the tested source build; no AUR helper is required.

## Package list

| Purpose | Packages |
| --- | --- |
| Build/download/review | `base-devel git curl less` |
| Bluetooth | `bluez bluez-utils` |
| Container | `podman` (rootless) |
| Discovery/diagnostics | `avahi iproute2 util-linux` (`rfkill` is in util-linux) |
| Display | `xorg-xhost`; `xorg-xwayland` when running under Wayland |
| Qt build and runtime | `qt5-base qt5-declarative qt5-location qt5-networkauth qt5-websockets qt5-speech qt5-multimedia qt5-quickcontrols2 qt5-quickcontrols qt5-graphicaleffects qt5-tools` |
| Qt Bluetooth/charts | `qt5-connectivity qt5-charts` — repository packages if available, otherwise AUR |
| NVIDIA only | Existing proprietary driver plus `nvidia-container-toolkit` |

Pacman/makepkg resolve transitive dependencies. A working desktop supplies the user D-Bus session. QZ publishes DIRCON itself; Avahi provides the diagnostic browser.

## Installer behaviour

- `--check` reports packages and planned actions without downloads or changes. It does not test sensors.
- `--jobs N` sets QZ/AUR build parallelism; default 2.
- Uses sudo only for package installation and enabling `bluetooth.service` / `avahi-daemon.service`. Records previous service states in the private install log.
- Builds QZ as the desktop user with the [recorded source revision](upstream-findings.md), SMTP submodule and [root-check patch](../patches/qz-linux-user-permissions.patch). Retains source and licence under `~/.local/opt/qdomyos-zwift/`.
- Preserves existing binaries/configurations. Different example files are written alongside settings as `.zwift-linux-example`; merge only the intended settings, including host networking and DIRCON. Rider-specific Zwift configuration can override the main config.
- Interrupted downloads/builds can be retried by rerunning. Existing applications are not upgraded. Qt ABI changes may require a QZ rebuild; the underlying build is recorded in [QZ notes](qz-installed.md).
- Logs live under `${XDG_STATE_HOME:-~/.local/state}/zwift-linux-ble-bridge/`; builds/downloads under `${XDG_CACHE_HOME:-~/.cache}/zwift-linux-ble-bridge/`. No account password is collected by the installer.
- No firewall changes, root QZ, Wine Bluetooth, container data deletion, or automatic trainer pairing.

The installer pins the tested QZ and netbrain launcher revisions. The upstream Zwift container still updates normally. AUR recipes are pinned to the [reviewed commits](upstream-findings.md); always review before running them.

Validation: on the supported platform, run `python -m unittest discover -s tests -v` (Python is needed only for these developer tests). System tools and builds are stubbed in temporary directories; these checks do not establish a successful fresh-machine installation or ride.

## Hybrid NVIDIA laptops

On a hybrid Intel/NVIDIA laptop, add this tested override to `$HOME/.config/zwift/config` if Zwift still selects Intel:

```bash
VGA_DEVICE_FLAG=(--device=nvidia.com/gpu=all)
CONTAINER_EXTRA_ARGS=(
  --env=__NV_PRIME_RENDER_OFFLOAD=1
  --env=__GLX_VENDOR_LIBRARY_NAME=nvidia
  --env=__VK_LAYER_NV_optimus=NVIDIA_only
)
```

Do not add this block on a system without NVIDIA CDI.


For missing CDI devices, follow [NVIDIA's CDI documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html). Use the distribution's driver/toolkit refresh mechanism after driver upgrades.

## Undoing installation

See [recorded host changes](host-changes.md). Preserve ride data and configuration before removing user-installed files. Restore only service states changed by this installer, using its log; review reverse dependencies before removing shared packages. Removing the upstream launcher does not require deleting its persistent ride volume.

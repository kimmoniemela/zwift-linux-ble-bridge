# Changes and rollback — 2026-09-09

No services, firewall rules, Bluetooth configuration, pairings, trust state, security services or Wine internals were changed.

| Change | Location | Reversal |
| --- | --- | --- |
| Upstream user launcher | `~/.local/bin/zwift` | Use inspected upstream `bin/install.sh --uninstall --auto-confirm`, or remove only this newly installed file |
| Upstream desktop entry/icon | `~/.local/share/applications/Zwift.desktop`, `~/.local/share/icons/hicolor/scalable/apps/zwift.svg` | Upstream uninstaller removes these |
| Host-network/GPU configuration | `~/.config/zwift/config`, mode 0600 | Remove this newly created file or edit the named options; source copy is `config/netbrain-zwift.conf` |
| Download/launch | Original stalled pull/launcher stopped during repair; successful retry log `/tmp/zwift-pull-retry.log`; recovered launch log `/tmp/zwift-baseline-recovered.log` | Stop only the specific running container `zwift-kimmo` if cancellation is requested; do not kill unrelated Podman/Wine processes |
| Runtime artifacts | Rootless Podman image cache; planned container/volume `zwift-kimmo` | After stopping this specific container, remove its image/volume only if their data is no longer wanted; the volume can contain account/ride data |
| Source inspection | `/tmp/zwift-linux-upstream/` | Delete only these temporary inspection checkouts when no longer needed |
| Failed QZ configure | `/tmp/zwift-linux-qz-build/` | Delete only this temporary build directory |

The upstream uninstaller deliberately retains image, volume and configuration. Do not assume uninstalling the launcher deletes them. The installed launcher is pinned for investigation (`DONT_CHECK=1`); select and verify an explicit update before changing that pin. The successfully pulled upstream `latest` image has manifest digest `sha256:48e91121d861c773ea720f95dd134eeb496b0beaea4dfc0603d71331f9b65ae8`. Container `3fc351b28ea0` was started as `zwift-kimmo` with host networking and privileged mode off.

Initial BLE discovery ran for 20 seconds; a later host check confirmed `Discovering: no`. No BLE device was manually connected.

This workspace's `.git` is an empty read-only directory, so these files are not a committed Git repository. No commit or push was performed.

## QZ additions — 2026-09-10

Installed nine native repository Qt packages plus locally built `qt5-connectivity` and `qt5-charts`; versions are recorded in `diagnostics/2026-09-10-qz/packages.txt`. Pacman completed its existing Snapper hooks (pre/post snapshots 70–73). No firewall, Bluetooth service, systemd unit, capability, setuid or desktop security changes were made.

QZ is installed in `~/.local/opt/qdomyos-zwift` with its source, GPL licence and single startup-permission patch. Added `~/.local/bin/qz` and `~/.local/share/applications/qdomyos-zwift.desktop`. Initial user settings are in `~/.config/Roberto Viola/qDomyos-Zwift.conf`; state/logs are in `~/.local/state/qdomyos-zwift`.

To undo QZ installation, close its specific application process, remove only these newly created user files/directories after preserving wanted settings/ride data, and review package reverse-dependencies before removing the eleven newly installed Qt packages. Do not blindly remove shared dependencies. This does not require changing the existing Zwift installation.

## NVIDIA Container Toolkit — 2026-09-10

Installed `nvidia-container-toolkit` and `libnvidia-container` 1.20.0-1.1 from the configured CachyOS repository. Existing NVIDIA driver 610.57.04 was retained. Pacman Snapper snapshots: 74 and 75. The distribution package's post-transaction hook generated `/etc/cdi/nvidia.yaml`; its hook regenerates this on toolkit/driver package changes. This distribution uses a pacman hook, not the systemd refresh units described in NVIDIA's generic documentation. No new services were enabled.

Backed up `~/.config/zwift/config` to `~/.config/zwift/config.before-nvidia-20260910`. Installed the updated `config/netbrain-zwift.conf`: NVIDIA CDI device, PRIME render offload, NVIDIA GLX vendor, and NVIDIA-only Optimus Vulkan selection. Host networking and unprivileged rootless Podman remain configured.

Validation: a temporary container using the already installed Zwift image passed `nvidia-smi -L`. A Vulkan graphics probe with the desktop X11 socket/authentication passed with exit 0 and enumerated only Quadro T2000 with Max-Q Design, NVIDIA proprietary driver 610.57.04, Vulkan 1.4.341. Temporary containers were removed automatically. No Zwift container was running before this change. In-game frame rate has not yet been measured.

Rollback: restore the configuration backup to `~/.config/zwift/config` before the next launch. If toolkit removal is desired, review package dependencies before removing the two newly installed packages and remove their generated `/etc/cdi/nvidia.yaml` only when no other container uses it. Do not remove the existing NVIDIA driver. No firewall or Bluetooth changes are needed.

Reference: [NVIDIA CDI documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html). The installed distribution package hook is authoritative for this host's automatic regeneration mechanism.

## Repository preparation — 2026-09-10

Initialized the local `main` branch without staging or committing files. Added GPL-3.0, ignore rules and consolidated dependency documentation. Installed checksum-verified GitHub CLI 2.100.0 as `~/.local/bin/gh` after stale pacman mirrors returned 404 without changing packages. Created the empty public GitHub repository and added it as `origin`; no project files were pushed.

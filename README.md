# zwift-linux-ble-bridge

Experimental phone-free Bluetooth bridge for Zwift on Linux:

```text
BLE trainer and heart-rate monitor
  → Linux BlueZ
  → native QDomyos-Zwift (QZ)
  → Wahoo DIRCON/WFTNP
  → Zwift in upstream netbrain/zwift with host networking
```

Linux owns Bluetooth. [QDomyos-Zwift](https://github.com/cagnulein/qdomyos-zwift) (QZ) runs natively and presents the devices to Zwift as a network trainer. Zwift runs through unmodified [netbrain/zwift](https://github.com/netbrain/zwift) with rootless Podman and host networking.

This is especially useful away from home when the phone is providing the Linux machine's internet hotspot and is unavailable or undesirable as a Zwift Companion Bluetooth bridge. The phone supplies internet only; trainer and sensor connections remain on Linux.

## Current status

Tested with a Zwift Hub: BLE connection, watts, cadence, DIRCON discovery and resistance response work. NVIDIA CDI is verified with a Quadro T2000. Manual calibration through this path, Garmin HRM-Dual, external power meters and long-ride reliability remain unverified.

This is a working experiment, not yet a one-command installer.

## Install

The tested platform is Arch-based CachyOS. After installing Linux itself:

1. Install BlueZ, rootless Podman, build tools and the listed Qt packages.
2. Review and build the AUR packages `qt5-connectivity` and `qt5-charts` as a normal user.
3. Install upstream netbrain/zwift and copy this repository's host-network configuration.
4. Build the tested QZ revision, apply the included normal-user patch and install the launcher/configuration.
5. Optionally configure NVIDIA Container Toolkit.

All commands and the complete package list are in **[Install on Arch/CachyOS](docs/dependencies.md)**. The guide starts after the Linux operating system and graphical desktop are installed.

## Run

1. Start `qz` and leave it open.
2. Start `zwift`.
3. Pair the QZ network trainer; do not select **Pair Through Phone**.

## Optional external power meter

QZ can combine power and cadence from a BLE meter such as Favero Assioma with resistance control from the trainer:

```text
BLE power meter → power and cadence ┐
                                    ├→ QZ → DIRCON → Zwift
BLE smart trainer → resistance      ┘
```

In QZ, select the awake meter under **Settings → Accessories → Power Sensor Options → Power Sensor**, then restart QZ. Keep the trainer as the main bike and pair only QZ in Zwift. Verify live power/cadence and retest ERG and SIM; external-meter power matching has not yet been tested here. Calibrate the meter with its manufacturer's supported method.

## Arch and AUR note

Built on Arch-based CachyOS. `qt5-connectivity` and `qt5-charts` came from reviewed **AUR PKGBUILDs** because they were absent from the configured repositories. AUR content is user-produced: review the PKGBUILD and sources, then build as a normal user. Exact revisions are in [upstream findings](docs/upstream-findings.md).

## Details

[Installation](docs/dependencies.md) · [setup notes](docs/qz-installed.md) · [acceptance tests](docs/manual-acceptance.md) · [upstream findings](docs/upstream-findings.md) · [investigation log](docs/investigation.md) · [rollback](docs/host-changes.md)

The repository is licensed under [GPL-3.0](LICENSE). The included QZ patch removes an unconditional root check; it adds no protocol code or privileges. Upstream projects retain their own licences. Never commit Zwift binaries, credentials, container data or personal ride logs.

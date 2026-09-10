# Native QZ installed — 2026-09-10

The Zwift Hub connects to QZ over BLE and exposes watts, cadence and resistance response to Zwift through DIRCON. Manual calibration through this path, Garmin HRM-Dual, external power meters and ride reliability remain untested.

## Start and test

1. Power the Zwift Hub and keep competing trainer apps disconnected.
2. Run `qz`, or open **QZ — Native Bluetooth Bridge** from the desktop application list. If QZ was already open before the trainer was powered, close and reopen it to start a fresh scan.
3. Select the actual Hub identity in QZ if prompted. QZ recognizes names starting with `ZWIFT HUB`; no guessed device address or exact advertised name has been saved.
4. Pedal and verify changing watts/cadence in QZ. Only then run `zwift` and test the network trainer's telemetry, ERG and SIM.
5. Add Garmin HRM-Dual through QZ's heart-rate device selection after the trainer baseline passes. HR selection is initially Disabled so an absent HR sensor cannot delay the trainer baseline.

QZ is configured for DIRCON output, virtual BLE output off, no fake devices, and optional proprietary shifting off. A real trainer advertisement is expected only after QZ constructs the virtual device for the trainer; absence while no trainer is connected is not a failure.

## Installed files

| Item | Location |
| --- | --- |
| Command | `~/.local/bin/qz` |
| Binary | `~/.local/opt/qdomyos-zwift/bin/qdomyos-zwift` |
| Source and licence | `~/.local/opt/qdomyos-zwift/source`, `~/.local/opt/qdomyos-zwift/LICENSE` |
| Local patch | `~/.local/opt/qdomyos-zwift/patches/qz-linux-user-permissions.patch` |
| Settings | `~/.config/Roberto Viola/qDomyos-Zwift.conf` |
| Logs and working data | `~/.local/state/qdomyos-zwift/` |
| Desktop entry | `~/.local/share/applications/qdomyos-zwift.desktop`; generate it from `packaging/qdomyos-zwift.desktop.in` by replacing both placeholders with absolute paths |

The `qz` command only starts native QZ in its private working directory. It does not orchestrate Zwift, assert sensor readiness, change services, or grant elevated privileges. Close it through its window. A headless diagnostic instance required SIGINT after SIGTERM did not promptly terminate it; any future orchestrator must account for this behavior and verify process exit.

## Build and patch

QZ version 2.22.0, upstream revision `f67a1f8e80dfa52b1ba8243237e67f7b12beba4f`, SMTP submodule `3fa4a0fe5797070339422cf18b5e9ed8dcb91f9c`. Native Qt package versions are recorded in the diagnostics directory.

The unmodified binary passed upstream's `-smoke-test`, but normal startup returned exit 255 with `Runme as root!`. The sole source patch removes that unconditional Linux UID check. It does not bypass BlueZ, D-Bus, filesystem or kernel access controls. Actual backend permissions still apply. No protocol code was added or changed.

Build recipe after installing the documented dependencies and applying `patches/qz-linux-user-permissions.patch` to that revision:

```sh
mkdir -p /tmp/qz-build
cd /tmp/qz-build
qmake "$HOME/.local/opt/qdomyos-zwift/source/src/qdomyos-zwift.pro" -after CONFIG-=ltcg CONFIG-=debug CONFIG+=release
make -j3
QT_QPA_PLATFORM=offscreen ./qdomyos-zwift -smoke-test
```

This uses the app-only project, Qt's translation generation, a release build, and no link-time optimization. It compiled successfully with the installed GCC 16/Qt 5.15.19 stack. QZ uses Qt private headers; rebuild after incompatible Qt package upgrades. Corresponding patched source and GPL licence are retained with the installation.

## Verification results and limits

- Native dependency builds, app compilation, linking and `SMOKE_OK`: passed.
- Normal-user process: UID 1000; no setuid, capabilities or root execution granted.
- Real QZ application window: registered with title `qDomyos-Zwift`; live BlueZ discovery produced device results.
- Real configuration: all fake-device flags false, DIRCON true, virtual BLE false, shifting flags false.
- Isolated upstream fake-bike test: Avahi resolved `Wahoo KICKR 9909` and `Wahoo HRM` to the host; SRV endpoints 36866 and 36867 respectively. TCP connections to both advertised endpoints passed. These ports were discovered, not assumed.
- Trainer service UUIDs: FTMS 1826, Cycling Power 1818, Cycling Speed/Cadence 1816. HR endpoint: 180D.
- The simulator was stopped and its sockets verified closed before leaving the real application running. The test configuration lives only under `/tmp/qz-transport-test`, not in the installed user's settings.
- UFW remained active: default incoming deny/outgoing allow. No firewall or mDNS service changes were required. The first browse had no records; later resolved advertisements succeeded. This is not yet an mDNS reliability test.
- Qt reports missing CAP_NET_ADMIN for determining BLE address type. Discovery works; whether this affects the actual Hub connection must be established by hardware testing before granting any capability.
- Upstream GUI logged initial QML binding/workout-database warnings while starting; the process and window remained alive. A direct XWayland window capture returned black, so it was not treated as visual proof of UI rendering.
- **User-observed:** Hub BLE connection, watts/cadence in QZ, Zwift pairing through DIRCON, and watts in Zwift.
- **User-observed:** trainer resistance response during the repeat Zwift test.
- **Not proven:** Garmin HR data, manual calibration, isolated ERG/SIM acceptance, reconnect behavior and ride reliability.

Transport records in `diagnostics/2026-09-10-qz/` are explicitly simulated. Private live logs remain outside the project.

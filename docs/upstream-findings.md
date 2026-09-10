# Upstream evidence — 2026-09-09

These are source findings, not live hardware results.

Update: native QZ installation and isolated transport verification completed on September 10; see [installed QZ](qz-installed.md). Package/build availability observations below describe the earlier discovery checkpoint.

| Project | Inspected commit |
| --- | --- |
| netbrain/zwift | `26ca0daa3af49e670d40811deaa4673d4a4ee9eb` |
| cagnulein/qdomyos-zwift | `f67a1f8e80dfa52b1ba8243237e67f7b12beba4f` |
| elfrances/wahoo-fitness-tnp | `c227ec8e64793401b3b67e03ac009c0973934159` |
| JuergenLeber/SHIFTR | `058695971df496a00249af63e3a123af19c93830` |

## Zwift container

The [current upstream connection guide](https://github.com/netbrain/zwift/blob/26ca0daa3af49e670d40811deaa4673d4a4ee9eb/docs/getting-started/connecting-devices.md) explicitly supports phone-free Direct Connect with `NETWORKING="host"`. The launcher passes that value to `--network`; its default is bridge. It supports rootless Podman and defaults privileged mode off. Host configuration files are sourced after environment variables, so validate the actual launch command and container network mode, not merely the calling environment.

Historical [QZ discussion #2994](https://github.com/cagnulein/qdomyos-zwift/discussions/2994) reports success with QZ on Linux and netbrain/zwift after switching to host networking. Controller comments there date to January 2025 and do not establish current complete controller forwarding.

## QZ native build

[Linux installation instructions](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/docs/10_Installation.md) use Debian package names. Do not execute them on CachyOS. Use the app project `src/qdomyos-zwift.pro` for the application-only build; the top-level project also includes tests.

The current [project include](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/src/qdomyos-zwift.pri) requires Qt 5 Bluetooth, positioning, networkauth, websockets, texttospeech, location, multimedia, charts and quickcontrols2 in addition to base/declarative. A local qmake configure attempt failed on exactly those missing modules.

Native package mapping:

| Qt requirement | Arch/CachyOS package | Availability observed |
| --- | --- | --- |
| Core/widgets/XML/SQL/private headers | qt5-base | Installed |
| Quick/QML | qt5-declarative | Installed |
| Bluetooth | qt5-connectivity | AUR 5.15.19-2; absent from configured pacman repositories |
| Charts | qt5-charts | AUR 5.15.19-1; absent from configured pacman repositories |
| Positioning/location | qt5-location | CachyOS repository |
| Network authentication | qt5-networkauth | Repository |
| WebSockets | qt5-websockets | CachyOS repository |
| Speech | qt5-speech | Repository |
| Multimedia | qt5-multimedia | Repository |
| Quick Controls | qt5-quickcontrols2; qt5-quickcontrols for older QML imports | Repository |
| QML graphical effects | qt5-graphicaleffects | Repository; imported by QZ QML |
| Translation tools | qt5-tools | Repository |

Qt HTTP Server is optional behind `qtHaveModule(httpserver)`; webengine is not an unconditional desktop build requirement. Avoid adding either just because an older installation recipe lists broad Qt packages. The SMTP submodule must be initialized. qmdnsengine is already tracked in this checkout, despite stale submodule instructions in the installation document. Other submodules should follow actual build references.

AUR recipes were inspected at `qt5-connectivity` commit `25871f43fe7d08a8261e62300ff95bff386af054` and `qt5-charts` commit `9c629b0186588f202ad6a96cd115d8b9874145d8`. They build pinned KDE Qt source revisions using qmake/make and package into INSTALL_ROOT. Both were subsequently built as the desktop user and their resulting packages installed through pacman. The first Bluetooth recipe download failed with a TLS EOF; retry succeeded without weakening TLS verification.

GitHub's latest release endpoint returned `nightly-2026-09-04`, with ARM Linux executables and Android/Windows assets, but no Linux x86_64 executable. Native compilation was therefore used. AUR content is user-produced and must be reviewed again before reproducing the build from current recipes; the recorded revisions only describe this installation.

## DIRCON and aggregation

The user identified a **Zwift Hub** and **Garmin HRM-Dual**, with the trainer unavailable for live testing. QZ's BLE device factory explicitly recognizes `ZWIFT HUB` in its FTMS branch. [Garmin's manual](https://www8.garmin.com/manuals/webhelp/hrm-dual/EN-US/GUID-26E43680-74CC-4CC7-946F-D5019AF632E4.html) confirms Bluetooth pairing support; QZ implements a generic standard Heart Rate service client. These findings support the planned baseline but do not establish successful connections.

Hub-specific caveat: in [ftmsbike.cpp](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/src/devices/ftmsbike/ftmsbike.cpp), SIM routing switches to `sendZwiftPlayInclination` only when a proprietary Zwift service is present and `gears_zwift_ratio` is enabled. That function's Linux branch logs an unimplemented protobuf message and returns. Keep the setting false for baseline FTMS testing (its current default). This limitation belongs to the optional proprietary path and does not justify new protocol code before testing ordinary FTMS.

In [virtualbike.cpp](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/src/virtualdevices/virtualbike.cpp), `dircon_yes` creates a DirconManager before the `virtual_device_bluetooth` check. Thus source supports network export while disabling the virtual BLE peripheral; this does not disable QZ's physical BLE client.

The [manager](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/src/devices/dircon/dirconmanager.cpp) groups services by virtual machine. In default bike mode it defines:

- `Wahoo KICKR <dircon_id>`: FTMS `1826`, Cycling Power `1818`, Cycling Speed/Cadence `1816`; optional proprietary service when enabled.
- `Wahoo HRM`: Heart Rate `180D`, measurement `2A37` from QZ's device heart-rate metric.

This is a logical service grouping, not one virtual device per physical BLE sensor. The source reads the shared device metrics; actual HR identity and advertisement must still be recorded from a running instance. Rouvy compatibility takes a different grouping path and is not part of the proposed baseline.

The [processor](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/src/devices/dircon/dirconprocessor.cpp) uses its bundled QMdnsEngine to advertise `_wahoo-fitness-tnp._tcp.local.` with `ble-service-uuids`, identity attributes and an SRV port. Avahi is a diagnostic client here; its presence alone does not mean QZ is advertising. Ports are assigned using a configurable base plus virtual machine index. Discover the actual SRV endpoint; never assume one fixed port for all services.

The inspected [WFTNP reference](https://github.com/elfrances/wahoo-fitness-tnp/blob/c227ec8e64793401b3b67e03ac009c0973934159/README.md) independently describes address/SRV/TXT discovery followed by TCP connection establishment. It is an unofficial specification; upstream implementation and live captures remain authoritative for this setup.

Current upstream includes [DIRCON/mDNS fix #4983](https://github.com/cagnulein/qdomyos-zwift/pull/4983), merged August 27, 2026: source addresses hostname resolution and declared capabilities. Keep that fix when selecting a baseline revision.

[FTMS write processing](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/src/characteristics/characteristicwriteprocessor2ad9.cpp) handles target power and indoor-bike simulation parameters. It forwards commands and invokes power/slope handling. This establishes an implemented control path, but not trainer-specific compatibility or successful physical resistance changes.

The [BLE manager](https://github.com/cagnulein/qdomyos-zwift/blob/f67a1f8e80dfa52b1ba8243237e67f7b12beba4f/src/devices/bluetooth.cpp) can attach an external power sensor and route its power/cadence signals into the existing bike. Verify precedence and continued trainer control with the actual hardware after the trainer/HR baseline.

## Click/Play extension

Three distinct paths must be tested separately: physical trainer control over DIRCON; proprietary trainer-side virtual shifting; physical controller communication.

Current QZ DIRCON code conditionally advertises the proprietary Zwift service and routes writes through `CharacteristicWriteProcessor0003`; that processor handles hub riding data, slope and gear requests. The feature name `zwift_play_emulator` is insufficient to conclude that Zwift sees a network controller.

QZ's BLE manager also consumes Click/Play inputs. The inspected Click path routes plus/minus through controller gear handlers to `bike::gearUp/gearDown` (with separate MyWhoosh handling). This is evidence supporting an experiment for **E**, QZ-local shifting. It is not proof of steering, braking, menus or native Zwift controller pairing over WFTNP.

[SHIFTR](https://github.com/JuergenLeber/SHIFTR/blob/058695971df496a00249af63e3a123af19c93830/README.md) implements trainer-side virtual shifting over Direct Connect, but explicitly describes using Apple TV's Bluetooth connections for Play controllers while its trainer uses Ethernet. It therefore does not demonstrate controller-over-DIRCON.

| Candidate | Evidence and next experiment |
| --- | --- |
| A: QZ complete network controller path | Unproven. Pair controller only to QZ, leave Wine without BLE and Companion off, then test Zwift controller discovery and individual buttons while tracing traffic. |
| B: extend WFTNP services | Trainer-side service exists in source. First establish which controller service/identity Zwift accepts over WFTNP; no extension justified yet. |
| C: Linux BLE bridge into Wine | Untested fallback; defer until network/QZ-local paths are ruled out. |
| D: Companion-compatible bridge | Last resort; no reverse engineering warranted by current evidence. |
| E: QZ consumes inputs and shifts locally | Supported by inspected call path; test physical resistance in SIM and document whether Zwift's displayed gear follows. |

Recent issue search also returned [Play button request #4608](https://github.com/cagnulein/qdomyos-zwift/issues/4608) and [Click v2/MyWhoosh resistance bug #4896](https://github.com/cagnulein/qdomyos-zwift/issues/4896). Titles/status alone do not establish Linux or Zwift network-controller support. Controller experiments remain separate from core acceptance.

## Licensing

QZ and SHIFTR carry GPLv3 licensing. The subsequent native QZ installation applies one documented Linux startup-permission patch; full corresponding source and the GPL licence are retained with that local binary. Preserve these and applicable corresponding-source obligations when distributing the modified build. SHIFTR was not modified.

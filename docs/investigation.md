# Investigation log

## 2026-09-09 — host boundary

- Observation: initial Bluetooth and networking inspection failed.
- Evidence: sandbox D-Bus/netlink `Operation not permitted`; bluetoothctl aborted. BlueZ package version readable.
- Hypothesis: sandbox isolation prevents host observation.
- Experiment: repeat read-only diagnostics outside sandbox.
- Result: active BlueZ/D-Bus/Avahi, powered/unblocked adapter, rootless Podman and active WLAN confirmed.
- Decision: run live host diagnostics outside sandbox; do not change Bluetooth configuration.

## 2026-09-09 — physical device discovery

- Observation: cached device list contained desktop peripherals/audio devices.
- Evidence: successful 20-second LE scan found TV, mower and anonymous advertisers, no identified cycling devices; no WFTNP records returned by Avahi.
- Hypothesis: cycling equipment is asleep, unavailable, out of range, or not yet identified.
- Experiment: request trainer/sensor models and availability; do not connect anonymous devices.
- Result: user subsequently identified Zwift Hub and Garmin HRM-Dual; trainer not yet available for testing.
- Decision: continue upstream and software baseline inspection; do not claim sensor discovery, connection or telemetry.

## 2026-09-09 — upstream netbrain architecture

- Observation: current upstream explicitly documents Direct Connect without Companion using `NETWORKING="host"`.
- Evidence: netbrain/zwift commit `26ca0daa3af49e670d40811deaa4673d4a4ee9eb`, docs/getting-started/connecting-devices.md and src/zwift.sh (`--network "${NETWORKING}"`). Default networking remains bridge; privileged mode defaults off.
- Hypothesis: unmodified upstream with host networking is suitable for the Zwift side.
- Experiment: inspect installer and launch script before installation; prepare native-host QZ investigation separately.
- Result: source support confirmed; application launch not yet tested.
- Decision: use upstream, rootless Podman and host networking. No Wine Bluetooth work and no integration launcher before manual acceptance.

## 2026-09-09 — Zwift installation and GPU boundary

- Observation: no existing user installation; NVIDIA driver present but NVIDIA container toolkit/CDI definitions absent.
- Evidence: inspected upstream installer; initial dry-run selected `--device=nvidia.com/gpu=all`, while neither CDI directory existed. Intel UHD and vulkan-intel are present.
- Hypothesis: existing Intel GPU can establish the application baseline without installing NVIDIA container support.
- Experiment: installed upstream launcher pinned to `26ca0daa3af49e670d40811deaa4673d4a4ee9eb`; invoked it with rootless Podman, host networking and `/dev/dri` passthrough. Persisted reviewed configuration to the previously absent `~/.config/zwift/config` with mode 0600 and repeated dry-run.
- Result: dry-run confirms `--network host`, `/dev/dri`, existing Xauthority, and no privileged flag. Image pull is still in progress as of approximately 18:13 EEST; no application-launch acceptance yet. Output is in `/tmp/zwift-baseline-launch.log`.
- Decision: leave the authorized upstream download/launch running. Confirm application/pairing screen before starting QZ. Do not confuse the pending launcher process with a running Zwift app.

## 2026-09-09 — native QZ preparation

- Observation: Qt 5 modules needed by QZ are missing.
- Evidence: app-only qmake configuration failed with unknown modules bluetooth, positioning, networkauth, websockets, texttospeech, location, multimedia, charts and quickcontrols2. pacman repository queries and AUR RPC identify native package routes; latest release metadata has no x86_64 Linux binary.
- Hypothesis: native repository packages plus reviewed AUR Qt Bluetooth/Charts builds support an unmodified application build.
- Experiment: resolve repository transaction using `pacman -Sp --needed`; inspect AUR recipes and QZ's project/submodule declarations.
- Result: nine repository Qt packages resolved; AUR recipes downloaded and reviewed. No dependency installation, compilation or QZ runtime test performed.
- Decision: finish Zwift baseline, then install native prerequisites and build QZ. Administrator authentication is needed for package installation; `sudo -n` is unavailable. Keep QZ outside containers.

## 2026-09-09 — target hardware confirmed

- Observation: user has a Zwift Hub trainer and Garmin HRM-Dual; trainer is not yet available.
- Evidence: user confirmation. Current QZ `bluetooth.cpp:1920` explicitly matches names beginning `ZWIFT HUB` in its FTMS device branch. Its generic HR client subscribes to the standard Heart Rate service/measurement. Garmin documents HRM-Dual Bluetooth support.
- Hypothesis: the ordinary FTMS trainer path plus QZ's standard BLE HR client is the appropriate initial baseline.
- Experiment: inspect Hub-specific control routing before selecting settings.
- Result: `gears_zwift_ratio` defaults false. When true and the proprietary service exists, SIM is routed through `sendZwiftPlayInclination`, whose Linux branch currently logs `implement zwift hub protobuf!` and returns. Ordinary FTMS routing remains separately implemented. This is a source-level limitation of the optional proprietary path, not a demonstrated failure of the baseline.
- Decision: retain `gears_zwift_ratio=false` and `zwift_play_emulator=false` for the first Hub test. Prove physical telemetry and FTMS ERG/SIM before considering controller/proprietary shifting extensions. Do not scan repeatedly while the trainer is unavailable.
- Software status: existing Podman pull was still running after 16 minutes, with approximately 1.4 GiB in temporary download storage; no Zwift container listed at that check.

## 2026-09-09 — stalled registry download

- Observation: initial pull remained active for about three hours without producing a completed image or container.
- Evidence: log recorded TCP connection reset, TLS handshake timeout and DNS timeout to Docker registry/CDN hosts. Its final retry showed no file growth across a ten-second sample. The active network had changed by the repair attempt.
- Hypothesis: network interruption/change left the original pull stalled; the new network may support a clean retry.
- Experiment: verify registry DNS and HTTPS over IPv4 and IPv6. Both returned the expected unauthenticated HTTP 401 in under one second. Stop only the original launcher PID 412947 and pull PID 412999; start a fresh upstream Podman pull without removing cache or changing networking/firewall configuration.
- Result: temporary download size grew by 175,967,130 bytes in 15 seconds, approximately 11.7 MB/s. New pull passed 1.18 GB by 21:06 EEST. Completion still pending at this checkpoint; log `/tmp/zwift-pull-retry.log`.
- Decision: monitor this retry through completion, then launch the configured upstream container and inspect actual network mode. A network change is a plausible contributor, not proof of the sole cause of the earlier failures.
- Registry metadata: `netbrain/zwift:latest` manifest digest `sha256:48e91121d861c773ea720f95dd134eeb496b0beaea4dfc0603d71331f9b65ae8`; 8,427,857,439 compressed bytes across 12 layers, including one 7,537,425,834-byte layer. Completed layers can remain cached despite an empty image list; partial large-layer transfer is not assumed resumable.

### Recovery result

The retry completed successfully (exit 0), verified/imported the image, and matched the registry manifest digest above. No firewall, DNS, IPv6 or system service configuration was changed. Transfer samples sustained roughly 11–12 MB/s; the final large layer reached its exact expected size before import finished.

Launched the configured upstream `zwift` command with `DONT_PULL=1`. Container `3fc351b28ea0` (`zwift-kimmo`) was running at verification; `Network=host`, `Privileged=false`. Selected container logs confirmed both `Zwift launcher started using wine` and `Zwift started using wine`. The container remained up at the 40-second check. This proves the pull is repaired and startup occurred, not a logged-in pairing screen or riding acceptance.

Recovery logs: `/tmp/zwift-pull-retry.log` and `/tmp/zwift-baseline-recovered.log`. No credentials were supplied by this investigation. Trainer is still unavailable; native QZ and all hardware/control tests remain pending.

## 2026-09-10 — native QZ installation completed

- Observation: user requested completion of QZ installation before the hardware test.
- Evidence: repository Qt packages installed successfully; reviewed Qt Bluetooth and Charts AUR recipes built and installed successfully. Full QZ app build produced 516 objects and linked without errors.
- Hypothesis: ordinary native BlueZ access can replace QZ's blanket root requirement for this architecture.
- Experiment: unmodified binary returned `SMOKE_OK` for upstream's smoke test but refused normal startup with exit 255 and `Runme as root!`. Removed only that unconditional UID gate, rebuilt, and ran with user UID 1000.
- Result: smoke passed; real QZ window exists and Bluetooth discovery produced device results. No elevated capabilities or root process were required for discovery. Qt's CAP_NET_ADMIN address-type informational message remains a hardware-test consideration.
- Decision: install patched QZ 2.22.0 in `~/.local/opt/qdomyos-zwift`, retain full corresponding source/licence/patch, provide `~/.local/bin/qz` and a desktop entry. Preserve standard FTMS baseline settings; defer capabilities and proprietary shifting until evidence requires them.

### Isolated DIRCON experiment

- Observation: hardware still unavailable; software transport can be checked with upstream's fake bike.
- Evidence: isolated XDG configuration under `/tmp/qz-transport-test`, distinct trainer ID 9909, virtual BLE off, physical filter deliberately nonmatching.
- Experiment: resolve `_wahoo-fitness-tnp._tcp` through Avahi and connect to each returned SRV endpoint.
- Result: `Wahoo KICKR 9909` on the discovered trainer endpoint exposes 1826/1818/1816; `Wahoo HRM` on the discovered HR endpoint exposes 180D. Both TCP connects passed. UFW remained enabled with incoming deny/outgoing allow, no rule changes. First browse was empty, later browse resolved; do not claim startup/reconnect reliability from this test.
- Decision: simulator results count only as software transport verification. SIGTERM did not promptly stop its process; SIGINT stopped it and closed listeners. Final process check showed only the real QZ instance (UID 1000), with all simulator flags disabled. Real QZ is open for the Hub connection test; physical telemetry, HR and ERG/SIM remain pending.

See [installation and garage instructions](qz-installed.md) for exact paths, build recipe, caveats and evidence.

## 2026-09-10 — User ride feedback and NVIDIA enablement

Observation: user reports real Hub telemetry reaches QZ and Zwift (watts work), calibration does not work and trainer feedback feels abnormal. GPU performance was low. ERG/SIM control and HR remain unproven.
Evidence: toolkit was absent; the Zwift configuration explicitly passed `/dev/dri` for the Intel baseline. Host NVIDIA driver works and identifies Quadro T2000. No Zwift container was running at inspection.
Hypothesis: enabling NVIDIA graphics may improve rendering performance; this does not establish trainer control or calibration support.
Experiment: installed the native distribution toolkit, used its generated CDI device, configured NVIDIA graphics selection in the existing upstream launcher's user configuration. A first Vulkan probe lacked desktop access and failed; repeated with the X11 socket and existing authentication.
Result: rootless Zwift-image GPU visibility and Vulkan initialization pass; Vulkan enumerates only the Quadro T2000 with NVIDIA 610.57.04. No game performance measurement yet.
Decision: retain NVIDIA configuration for the next `zwift` launch. Investigate trainer control separately; leave native QZ and Bluetooth untouched. See `docs/host-changes.md` for backup and reversal.

## 2026-09-11 — Missing activity feed entries

- Observation: saved test rides were absent from the Zwift website activity feed.
- Evidence: two finalized FIT files survived container removal in the persistent Podman volume. Local logs contain final save/upload attempts and the save screen reaching Done.
- Hypothesis: short test rides fall below Zwift's minimum cycling distance for feed publication.
- Experiment: decode both FIT session summaries with CRC validation and compare their distances with the local log summaries and [Zwift support's 2 km requirement](https://forums.zwift.com/t/not-saving-rides/652618/4).
- Result: both files pass CRC validation and both distances are below 2 km. The evidence supports the distance threshold explanation; it does not prove feed publication for a qualifying ride.
- Decision: no runtime configuration change. Add a 3 km save-and-feed check to the README and acceptance gates. Keep personal FIT files and raw logs outside the repository.

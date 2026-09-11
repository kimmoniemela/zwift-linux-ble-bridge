# Manual acceptance gates

Native QZ installation, application startup, BLE discovery and an isolated simulated DIRCON transport check are complete; see [installed QZ](qz-installed.md). The user has also observed live Zwift Hub watts/cadence in QZ, watts in Zwift through DIRCON and trainer resistance response. Formal ERG/SIM control acceptance, heart rate and reliability gates remain pending unless explicitly recorded as passed with evidence in the investigation log.

Target equipment: **Zwift Hub** and **Garmin HRM-Dual**. Capture firmware and exact advertised device names during later diagnostics; do not invent names or addresses in configuration.

## 1. Zwift baseline

Use the installed upstream `zwift` launcher. Review the host configuration in `config/netbrain-zwift.conf`; it selects rootless Podman and host networking. NVIDIA CDI setup is optional and documented in the [installation guide](../README.md#1-install). Do not use privileged mode or expose system Bluetooth to Wine.

Confirm a visible Zwift application window and then the pairing screen, with QZ stopped. Handle account login locally; never put credentials in this repository or chat. Upstream also supports credentials in its private user configuration because its Wine launcher login page has limitations; use its documented authentication route if necessary, with restrictive file permissions and debugging disabled. Record the upstream launcher revision, container image digest and `podman inspect --format '{{.HostConfig.NetworkMode}}' zwift-kimmo`. An exited container, successful image pull or launcher success message alone does not pass this gate.

## 2. Native QZ and trainer only

After gate 1, install every mapped package and build upstream QZ using the [installation guide](../README.md#1-install). The repository packages and reviewed AUR Qt Bluetooth/Charts builds were installed successfully on September 10. On a fresh host, recheck package state and build the AUR packages as an ordinary user. The installed QZ build removes upstream's blanket root gate; it does not grant elevated system permissions. Preserve native package lists before/after to make rollback precise; do not blindly remove shared Qt dependencies.

Use the current app-only source project, initialize its SMTP submodule and generate translation resources if required. Run qmake and make as the desktop user. Optional HTTP-server support is separate from DIRCON; do not make it a prerequisite without a demonstrated need.

Obtain trainer model/firmware and its exact advertised identity. Wake the trainer and stop other apps that might claim it. Let QZ own the BLE connection. Initially disable external HR/power/controller inputs. Select the intended trainer in QZ and retain diagnostic logs. For a network-only virtual trainer, QZ provides `virtual_device_bluetooth=false` while `dircon_yes=true`; verify the effective settings in the chosen GUI/CLI mode.

Record four separate states: discovered, connected, producing live telemetry, exported. Pedal and record changing watts/cadence and speed if provided by the trainer. A connected flag or a zero-filled tile does not prove data flow. Do not proceed to Zwift pairing until QZ's physical telemetry is demonstrated.

**CLI caveat:** inspected `main.cpp` writes several default options back to QSettings in non-QML mode, including virtual Bluetooth, power source and controller flags. Do not assume settings saved through the GUI survive an arbitrary `-no-gui` invocation. Prefer GUI baseline first and check effective CLI settings later.

**Hub baseline:** keep `gears_zwift_ratio=false` and `zwift_play_emulator=false` (both current defaults). In the inspected FTMS implementation, enabling the former can redirect SIM commands into a proprietary Hub encoder whose Linux implementation is missing. Test ordinary FTMS first; this does not yet establish compatibility with the actual Hub firmware.

## 3. WFTNP independently

With QZ running and Zwift stopped:

```sh
avahi-browse --resolve --terminate --parsable _wahoo-fitness-tnp._tcp
ss -lntp
```

Save the resolved instance name, interface/address family, SRV hostname, address, port and TXT `ble-service-uuids`. Resolve the SRV target; confirm its address belongs to this host and matches the address family of the listener. Correlate the advertised port to QZ's actual listening socket. Repeat for HR when it is added. Defaults in source are not observed endpoints.

For each chosen resolved endpoint, use a plain TCP connection probe with a bounded timeout (for example `nc -vz -w 3 <resolved-address> <SRV-port>` if netcat is installed). Close the probe before pairing Zwift. A successful TCP handshake proves reachability only; it does not prove GATT discovery, notifications or control. No new protocol implementation is required for this probe.

If advertisement fails, investigate QZ's bundled mDNS publisher and its log. Avahi being active does not prove QZ export. If TCP fails, check address selection, listener and effective firewall rules before changing anything. Keep UFW enabled; add a narrowly scoped reversible rule only if captures/rules identify filtering. Do not hard-code 36866.

## 4. Zwift telemetry and control

Keep Companion stopped and choose the network/Direct Connect source, not Pair Through Phone. Pair the intended QZ virtual trainer for Power, Resistance/Controllable and Cadence. Record identities and changing values simultaneously in QZ and Zwift.

For ERG, use a short workout with clearly changing target watts at comfortable levels selected by the rider. Correlate the Zwift target, DIRCON write, QZ interpretation, BLE trainer command/response and physically felt resistance change. Record target versus measured power over time. A successful DIRCON acknowledgement alone is insufficient.

For SIM, use a route with a meaningful gradient change and nonzero trainer difficulty. Correlate gradient, DIRCON write, QZ/BLE handling and physical resistance. Record rider confirmation. Do not generate unsolicited high-load trainer commands.

## 5. HR, then optional external power

After trainer acceptance, attach the intended BLE HR monitor in QZ. Confirm physiological readings change and remain stable in QZ, then resolve the resulting WFTNP records and pair HR in Zwift. Default source suggests a separate logical Wahoo HRM; document actual running behavior rather than assuming one endpoint per physical sensor.

Only then configure an external power meter if available. Confirm the intended source in QZ using device-specific notification evidence, not merely similar watt values. Recheck trainer ERG/SIM control and Zwift power. Record sensor precedence and cadence selection.

For a BLE cycling power meter such as Favero Assioma, wake the sensor and select its advertised name under **Settings → Accessories → Power Sensor Options → Power Sensor**, then restart QZ. Leave the controllable trainer as QZ's main bike. The inspected QZ implementation connects the selected power sensor separately, replaces the main bike's power and cadence with its measurements, and retains the trainer for resistance commands. Pair the aggregated QZ network trainer in Zwift rather than attempting a direct Wine Bluetooth connection to the meter.

Verify the complete split path independently: pedal power/cadence → QZ → DIRCON → Zwift, and Zwift ERG/SIM commands → QZ → trainer. External-power ERG uses QZ's power-matching logic, so repeat target-change tests and watch for oscillation, lag or an incorrect offset. Perform any activation, firmware update and calibration/zero offset through the meter manufacturer's supported procedure; QZ selecting the sensor does not calibrate it.

## 6. Activity saving

Ride at least 3 km, select End Ride and Save, and confirm the activity appears on the Zwift website. Zwift requires at least 2 km for a cycling activity to appear in its feed; short tests cannot pass this gate. Quit the game normally and wait for the launcher to finish synchronizing. Verify the finalized FIT file survives in the persistent Podman volume after the container exits. Local FIT creation, an upload attempt and a visible feed entry are separate checks.

## 7. Reliability and orchestration

Run a normal-length ride with timestamped telemetry/control evidence, then exercise one fault at a time: trainer power cycle, BLE reconnect, DIRCON client disconnect/reconnect, QZ restart, Zwift restart, mDNS interruption, multiple sensors and suspend/resume if relevant. Define expected reconnection behavior before each experiment and record recovery time/data gaps.

Restore unnecessary experimental changes after each failed hypothesis. Keep an inventory of processes started by the test; terminate only those. Container ownership must include the specific name/ID, not every Wine or Podman process.

Create `bin/zwift-linux` and systemd integration only after these gates pass. Its readiness checks must use observable state and distinguish transport availability from live metrics, Zwift pairing and control acceptance. Any eventual fresh-system claim also requires a documented clean installation test on each supported distribution.

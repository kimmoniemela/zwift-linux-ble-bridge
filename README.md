# zwift-linux-ble-bridge

Bluetooth trainers and sensors → **native QZ on Linux** → **DIRCON** → **Zwift**. No Zwift Companion phone bridge needed.

This uses [netbrain/zwift](https://github.com/netbrain/zwift) for the game and adds [QDomyos-Zwift (QZ)](https://github.com/cagnulein/qdomyos-zwift) for Bluetooth. Handy when travelling and using your phone as the laptop's internet hotspot.

## Requirements

- **Arch/CachyOS, x86-64**, with a working graphical desktop and graphics driver. Other distributions are not supported by this installer yet.
- Bluetooth adapter, compatible BLE trainer, internet connection and Zwift account.
- 8 GB RAM and at least 15 GB free for Zwift, plus QZ build space.
- An up-to-date system and access to `sudo`. Run the installer as your **normal desktop user**.

## 1. Install

Open a terminal and run:

```bash
sudo pacman -S --needed git
git clone https://github.com/kimmoniemela/zwift-linux-ble-bridge.git
cd zwift-linux-ble-bridge
./install.sh
```

The installer installs the dependencies, enables Bluetooth/Avahi, builds native QZ, runs the **upstream netbrain/zwift installer**, and configures host networking and DIRCON. With a loaded proprietary NVIDIA driver it also installs NVIDIA Container Toolkit. It preserves existing binaries and settings; if it leaves `.zwift-linux-example` files, compare those with your configuration before riding.

**AUR:** `qt5-connectivity` and `qt5-charts` come from reviewed, pinned AUR recipes when unavailable in the repositories. The installer opens each missing package's recipe for review (`q` to exit), asks before building it, and uses `makepkg` as your normal user. Downloads and compilation can take a while; progress and a private log path are shown.

Use `./install.sh --check` to preview dependencies and actions without changes, or `./install.sh --jobs 4` to build with four workers (default: two). If a step fails, read the reported error and rerun after resolving it. The installer does not upgrade existing QZ or Zwift launchers.

## 2. Set up Zwift login

In a **Bash terminal**, make the installed commands available:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add that line to `~/.bashrc` if needed for future Bash terminals. Skip the next block if your existing Zwift login already works. Otherwise enter your account details when prompted; your password is hidden and stored as a Podman secret:

```bash
read -r -p 'Zwift email: ' zwift_email
read -r -s -p 'Zwift password: ' zwift_password
printf '\n'
if printf '%s' "$zwift_password" | podman secret create --replace=true "zwift-password-$zwift_email" -; then
    printf 'ZWIFT_USERNAME=%q\n' "$zwift_email" >> "$HOME/.config/zwift/config"
else
    printf 'Could not store login. Resolve the Podman error before starting Zwift.\n'
fi
unset zwift_password
unset zwift_email
```

Once login is stored, run `zwift`. The first launch downloads the game container. Wait for it to reach the home/pairing screen, then quit normally. The Wine launcher login page has limitations, which is why we use upstream's account/secret support above. [Upstream setup and troubleshooting](https://github.com/netbrain/zwift/tree/master/docs).

## 3. Connect the trainer

1. Power the trainer and disconnect other apps that might claim its Bluetooth connection.
2. Run `qz`. If it does not select your trainer, use **Settings → Advanced Settings → Manual Device**, select it, click **OK**, and restart QZ. Use **Refresh Devices List** if needed.
3. Pedal until QZ shows changing **watts and cadence**. Keep QZ open.
4. Run `zwift` in another terminal. Pair QZ's **Wahoo KICKR …** network device for **Power Source**, **Resistance / Controllable**, and **Cadence**. Do not select **Pair Through Phone**.

## 4. Verify your first ride

Check live watts/cadence in Zwift, then test changing ERG targets and a gradient change in free ride. Resistance should respond in both cases.

Ride **3 km**, choose **End Ride → Save**, and check the Zwift website feed. Cycling activities must reach **2 km** to appear online ([Zwift support](https://forums.zwift.com/t/not-saving-rides/652618/4)); short connection tests may only leave local FIT files. Quit Zwift normally and wait for its terminal to return before closing QZ.

**Every ride:** start `qz`, wait for live trainer data, then start `zwift`. Keep QZ open until the ride is saved and Zwift has exited.

## Optional sensors

In QZ's **Settings**, choose the awake sensor, click **OK**, and restart QZ:

- **Heart rate:** **Heart Rate Options → Heart Belt Name**. Verify live HR in QZ, then select QZ's HR source in Zwift (it may appear as **Wahoo HRM**).
- **Favero Assioma or another BLE power meter:** **Accessories → Power Sensor Options → Power Sensor**. Keep the trainer as the main device for resistance. Verify the intended power source and retest ERG/SIM; calibrate the meter using its manufacturer's supported method.

## Troubleshooting

| Problem | First check |
| --- | --- |
| Trainer missing in QZ | Wake it, disconnect competing apps; check `bluetoothctl list` and `rfkill list bluetooth`. |
| QZ has watts; Zwift sees no device | Confirm `NETWORKING="host"` in `~/.config/zwift/config`. Run `avahi-browse --resolve --terminate --parsable _wahoo-fitness-tnp._tcp` and compare the advertised port with `ss -lntp`. Keep the firewall enabled. |
| Low NVIDIA performance | Check `nvidia-smi` and `nvidia-ctk cdi list`; see [hybrid GPU settings](docs/dependencies.md#hybrid-nvidia-laptops). |
| Ride missing online | Check distance (2 km minimum) and whether Save completed. Local FIT files are in `Activities` under the path from `podman volume inspect "zwift-$USER" --format '{{.Mountpoint}}'`. |

## Status and credits

Tested manually on CachyOS with a Zwift Hub: BLE telemetry, DIRCON pairing and resistance response. NVIDIA CDI works with a Quadro T2000. **The installer has automated safety checks but still needs a fresh-machine installation test.** Garmin HRM-Dual, external meters, isolated ERG/SIM acceptance and long-ride reliability remain unverified. Manual calibration and Click/Play are not established through this bridge.

[Dependencies and installer details](docs/dependencies.md) · [Acceptance tests](docs/manual-acceptance.md) · [Upstream evidence](docs/upstream-findings.md) · [Investigation log](docs/investigation.md) · [Rollback](docs/host-changes.md)

[GPL-3.0](LICENSE). This wrapper uses upstream netbrain/zwift and QZ with a small patch removing its unconditional Linux root check. Preserve applicable QZ source/licensing obligations when distributing patched builds. Keep credentials, Zwift binaries and personal ride files out of this repository.

# Install on Arch/CachyOS

This guide installs the bridge software after Linux and a graphical desktop are working. The tested revisions are pinned for reproducibility; review upstream changes before updating them.

Requirements: x86-64 Linux, 8 GB RAM, about 15 GB free storage, working graphics, internet access and a Bluetooth adapter. Run QZ from a normal graphical user session so it can access D-Bus and BlueZ.

## 1. Install repository packages

Use the distribution's normal full-system update first, then install:

```sh
sudo pacman -S --needed base-devel git curl bluez bluez-utils podman avahi \
  iproute2 rfkill xorg-xhost qt5-base qt5-declarative qt5-location \
  qt5-networkauth qt5-websockets qt5-speech qt5-multimedia \
  qt5-quickcontrols2 qt5-quickcontrols qt5-graphicaleffects qt5-tools

sudo systemctl enable --now bluetooth.service avahi-daemon.service
```

Podman runs rootless and does not need a system daemon. Avahi supplies the diagnostic browser used below; QZ publishes its own DIRCON advertisement.

## 2. Build the two AUR dependencies

`qt5-connectivity` and `qt5-charts` were unavailable in the configured repositories. AUR content is user-produced: inspect each PKGBUILD and its sources before building. Never run `makepkg` as root.

```sh
mkdir -p "$HOME/.cache/zwift-linux-ble-bridge/aur"
cd "$HOME/.cache/zwift-linux-ble-bridge/aur"

git clone https://aur.archlinux.org/qt5-connectivity.git
git clone https://aur.archlinux.org/qt5-charts.git

cd qt5-connectivity
less PKGBUILD
makepkg --syncdeps --install --clean

cd ../qt5-charts
less PKGBUILD
makepkg --syncdeps --install --clean
```

The builds tested here used `qt5-connectivity` 5.15.19-2 and `qt5-charts` 5.15.19-1. Their reviewed AUR commits are recorded in [upstream findings](upstream-findings.md).

## 3. Clone this repository

```sh
mkdir -p "$HOME/.local/src"
git clone https://github.com/kimmoniemela/zwift-linux-ble-bridge.git \
  "$HOME/.local/src/zwift-linux-ble-bridge"
cd "$HOME/.local/src/zwift-linux-ble-bridge"
```

The remaining commands that mention “this repository's root” use that directory.

## 4. Install netbrain/zwift

Use upstream netbrain/zwift rather than a fork. The commands below avoid piping a downloaded script directly into a shell:

```sh
mkdir -p "$HOME/.local/src"
git clone https://github.com/netbrain/zwift.git "$HOME/.local/src/netbrain-zwift"
cd "$HOME/.local/src/netbrain-zwift"
git checkout 26ca0daa3af49e670d40811deaa4673d4a4ee9eb
less bin/install.sh
./bin/install.sh --script-version 26ca0daa3af49e670d40811deaa4673d4a4ee9eb --auto-confirm
```

From this repository's root, install the tested rootless and host-network configuration:

```sh
cd "$HOME/.local/src/zwift-linux-ble-bridge"
install -d -m 700 "$HOME/.config/zwift"
install -m 600 config/netbrain-zwift.conf "$HOME/.config/zwift/config"
```

The first `zwift` launch downloads a large container image. Keep account credentials out of this repository; follow netbrain/zwift's secret-store instructions if automatic login is needed.

## 5. Build and install native QZ

Run these commands from this repository's root:

```sh
cd "$HOME/.local/src/zwift-linux-ble-bridge"
BRIDGE_ROOT="$PWD"
QZ_PREFIX="$HOME/.local/opt/qdomyos-zwift"
QZ_SOURCE="$QZ_PREFIX/source"
QZ_BUILD="$HOME/.cache/zwift-linux-ble-bridge/qz-build"

mkdir -p "$QZ_PREFIX" "$QZ_BUILD"
git clone https://github.com/cagnulein/qdomyos-zwift.git "$QZ_SOURCE"
cd "$QZ_SOURCE"
git checkout f67a1f8e80dfa52b1ba8243237e67f7b12beba4f
git submodule update --init src/smtpclient
git apply --unidiff-zero "$BRIDGE_ROOT/patches/qz-linux-user-permissions.patch"

cd "$QZ_BUILD"
qmake "$QZ_SOURCE/src/qdomyos-zwift.pro" \
  -after CONFIG-=ltcg CONFIG-=debug CONFIG+=release
make -j2

install -Dm 755 qdomyos-zwift "$QZ_PREFIX/bin/qdomyos-zwift"
install -Dm 644 "$QZ_SOURCE/LICENSE" "$QZ_PREFIX/LICENSE"
install -Dm 644 "$QZ_SOURCE/src/icons/icon.png" "$QZ_PREFIX/icon.png"
install -Dm 644 "$BRIDGE_ROOT/patches/qz-linux-user-permissions.patch" \
  "$QZ_PREFIX/patches/qz-linux-user-permissions.patch"
install -Dm 755 "$BRIDGE_ROOT/packaging/qz" "$HOME/.local/bin/qz"

install -d -m 700 "$HOME/.config/Roberto Viola"
install -m 600 "$BRIDGE_ROOT/config/qdomyos-zwift.conf" \
  "$HOME/.config/Roberto Viola/qDomyos-Zwift.conf"
```

The patch only removes QZ's unconditional root check. It does not add privileges or change protocol handling. Keep the checked-out source and GPL licence with any distributed patched binary.

Optional desktop entry:

```sh
install -d -m 755 "$HOME/.local/share/applications"
sed -e "s|@QZ_LAUNCHER@|$HOME/.local/bin/qz|" \
    -e "s|@QZ_ICON@|$HOME/.local/opt/qdomyos-zwift/icon.png|" \
    "$BRIDGE_ROOT/packaging/qdomyos-zwift.desktop.in" \
    > "$HOME/.local/share/applications/qdomyos-zwift.desktop"
chmod 644 "$HOME/.local/share/applications/qdomyos-zwift.desktop"
```

Ensure `$HOME/.local/bin` is on `PATH`, or start the commands by their full paths.

## 6. Optional NVIDIA graphics

Install a working proprietary NVIDIA driver using the distribution's normal method first. Then install CDI support:

```sh
sudo pacman -S --needed nvidia-container-toolkit
nvidia-smi
nvidia-ctk cdi list
```

Upstream netbrain/zwift normally detects NVIDIA CDI. On a hybrid Intel/NVIDIA laptop, add this tested override to `$HOME/.config/zwift/config` if Zwift still selects Intel:

```sh
VGA_DEVICE_FLAG=(--device=nvidia.com/gpu=all)
CONTAINER_EXTRA_ARGS=(
  --env=__NV_PRIME_RENDER_OFFLOAD=1
  --env=__GLX_VENDOR_LIBRARY_NAME=nvidia
  --env=__VK_LAYER_NV_optimus=NVIDIA_only
)
```

Do not add this block on a system without NVIDIA CDI.

## 7. Start and verify

Power the trainer and close other apps that could claim its Bluetooth connection. Start QZ first:

```sh
qz
```

In QZ, select the trainer and verify changing watts and cadence while pedalling. Keep QZ open. Confirm that DIRCON is advertised and listening:

```sh
avahi-browse --resolve --terminate --parsable _wahoo-fitness-tnp._tcp
ss -lntp
```

Then start Zwift:

```sh
zwift
```

Pair the QZ network trainer for power, controllable/resistance and cadence. Do not choose **Pair Through Phone**. Verify telemetry, then test ERG and SIM resistance separately. Add heart rate or an external power meter only after the trainer baseline works; see [acceptance tests](manual-acceptance.md).

#!/usr/bin/env bash
# Install the tested native-QZ / upstream-Zwift setup on Arch and derivatives.
set -Eeuo pipefail
umask 077

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
QZ_REV=f67a1f8e80dfa52b1ba8243237e67f7b12beba4f
ZWIFT_REV=26ca0daa3af49e670d40811deaa4673d4a4ee9eb
PACKAGES=(base-devel git curl less bluez bluez-utils podman avahi iproute2
    util-linux xorg-xhost qt5-base qt5-declarative qt5-location qt5-networkauth
    qt5-websockets qt5-speech qt5-multimedia qt5-quickcontrols2
    qt5-quickcontrols qt5-graphicaleffects qt5-tools)
PREFIX="$HOME/.local/opt/qdomyos-zwift"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zwift-linux-ble-bridge"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/zwift-linux-ble-bridge"
BIN="$HOME/.local/bin"
QZ_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/Roberto Viola/qDomyos-Zwift.conf"
ZWIFT_CONFIG="$HOME/.config/zwift/config"
JOBS=2
CHECK=0
LOG=''

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
say() { printf '\n%s\n' "$*"; }
usage() {
    cat <<'EOF'
Usage: ./install.sh [--check] [--jobs N]

Install native QZ and upstream netbrain/zwift on x86-64 Arch/CachyOS.
Run as your desktop user, never with sudo. Individual package/service steps
request sudo. AUR recipes require review and confirmation before makepkg.

  --check     Show dependencies and planned actions; make no changes or downloads.
  --jobs N    QZ/AUR build parallelism (default: 2).
  --help      Show this help.

Existing binaries, launchers and settings are preserved. This is an installer,
not an updater. It does not start Zwift/QZ or verify physical sensors.
EOF
}
confirm() {
    local answer
    read -r -p "$1 [y/N] " answer
    [[ $answer == y || $answer == Y ]] || die 'Cancelled; completed steps were retained. Rerun to continue.'
}
run_logged() { "$@" 2>&1 | tee -a "$LOG"; }

# Do not overwrite a user's setup. Leave the proposed file next to it instead.
install_preserving() {
    local source=$1 target=$2 mode=$3
    [[ ! -L $target ]] || die "Refusing symlink destination: $target"
    if [[ -e $target ]]; then
        [[ -f $target ]] || die "Not a regular file: $target"
        if ! cmp -s -- "$source" "$target"; then
            [[ ! -L $target.zwift-linux-example ]] || die 'Example destination is a symlink.'
            install -m "$mode" -- "$source" "$target.zwift-linux-example"
            printf 'Preserved %s; compare %s.zwift-linux-example\n' "$target" "$target"
        fi
    else
        install -Dm "$mode" -- "$source" "$target"
    fi
}

checkout_source() {
    local url=$1 destination=$2 revision=$3
    if [[ ! -e $destination ]]; then
        run_logged git clone -- "$url" "$destination"
        run_logged git -C "$destination" checkout --detach "$revision"
    fi
    [[ ! -L $destination && -d $destination/.git ]] || die "Invalid checkout: $destination"
    [[ $(git -C "$destination" remote get-url origin) == "$url" ]] || die "Unexpected source origin: $destination"
    # A clone interrupted before checkout can be resumed without discarding edits.
    if [[ $(git -C "$destination" rev-parse HEAD) != "$revision" ]]; then
        [[ -z $(git -C "$destination" status --porcelain) ]] || die "Preserve local edits before retrying: $destination"
        run_logged git -C "$destination" checkout --detach "$revision"
    fi
}

install_aur() {
    local package=$1 revision=$2 source="$CACHE/aur/$1-$2"
    if pacman -Q "$package" >/dev/null 2>&1; then
        printf 'Already installed: %s\n' "$package"
        return
    fi
    # Prefer official repositories if the distribution now provides this module.
    if pacman -Si "$package" >/dev/null 2>&1; then
        run_logged sudo pacman -S --needed "$package"
        return
    fi
    checkout_source "https://aur.archlinux.org/$package.git" "$source" "$revision"
    say "Review AUR files and sources in $source (press q to leave less)."
    LESSSECURE=1 less -- "$source/PKGBUILD"
    confirm "Build and install $package from this AUR recipe?"
    (cd "$source"; run_logged env MAKEFLAGS="-j$JOBS" makepkg --syncdeps --install --clean)
}

main() {
    while (($#)); do
        case $1 in
            --help|-h) usage; return ;;
            --check) CHECK=1 ;;
            --jobs)
                (($# >= 2)) || die '--jobs needs a positive integer.'
                [[ $2 =~ ^[1-9][0-9]*$ ]] || die '--jobs needs a positive integer.'
                JOBS=$2; shift ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done
    [[ $EUID -ne 0 ]] || die 'Run as your normal desktop user, without sudo.'
    [[ $(uname -m) == x86_64 ]] || die 'Only x86-64 is supported by this installer.'
    [[ -r /etc/os-release ]] || die 'Cannot identify this distribution.'
    # /etc/os-release is distribution-owned shell metadata.
    source /etc/os-release
    [[ " ${ID:-} ${ID_LIKE:-} " == *' arch '* || ${ID:-} == cachyos ]] || die 'This installer supports Arch/CachyOS only. See upstream for other distributions.'
    command -v pacman >/dev/null || die 'pacman is required.'
    [[ -f $ROOT/config/netbrain-zwift.conf && -f $ROOT/packaging/qz ]] || die 'Run this installer from a complete repository checkout.'
    if [[ -f /proc/driver/nvidia/version ]]; then
        PACKAGES+=(nvidia-container-toolkit)
    fi
    if [[ -n ${WAYLAND_DISPLAY:-} ]]; then PACKAGES+=(xorg-xwayland); fi

    say 'Arch/CachyOS setup: native QZ + rootless Podman + host networking'
    printf 'Repository dependencies:\n'
    local package
    for package in "${PACKAGES[@]}" qt5-connectivity qt5-charts; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            printf '  installed  %s\n' "$package"
        else
            printf '  needed     %s\n' "$package"
        fi
    done
    printf '\nEnable Bluetooth and Avahi; install missing QZ and Zwift binaries.\n'
    printf 'Keep existing settings and binaries. New settings enable DIRCON/host networking.\n'
    printf 'No firewall changes, Wine Bluetooth, account setup or sensor connections.\n'
    if ((CHECK)); then return; fi
    [[ -t 0 ]] || die 'Use an interactive terminal for package and AUR review.'
    command -v sudo >/dev/null || die 'sudo is required for package/service installation.'
    confirm 'Proceed with installation on an up-to-date Arch/CachyOS system?'
    mkdir -p -- "$CACHE/aur" "$STATE" "$BIN"
    exec 9>"$STATE/install.lock"
    flock -n 9 || die 'Another installer is using this state directory.'
    LOG=$(mktemp "$STATE/install-XXXXXXXX.log")
    printf 'Build/install log: %s\n' "$LOG"
    trap 'printf "Installation stopped. Completed steps are retained; see %s\n" "$LOG" >&2' ERR
    run_logged sudo pacman -S --needed "${PACKAGES[@]}"
    install_aur qt5-connectivity 25871f43fe7d08a8261e62300ff95bff386af054
    install_aur qt5-charts 9c629b0186588f202ad6a96cd115d8b9874145d8
    {
        printf 'Service state before installation:\n'
        systemctl is-enabled bluetooth.service avahi-daemon.service || true
        systemctl is-active bluetooth.service avahi-daemon.service || true
    } >> "$LOG" 2>&1
    run_logged sudo systemctl enable --now bluetooth.service avahi-daemon.service

    if [[ ! -e $BIN/zwift && ! -L $BIN/zwift ]]; then
        local upstream="$CACHE/netbrain-$ZWIFT_REV"
        checkout_source https://github.com/netbrain/zwift.git "$upstream" "$ZWIFT_REV"
        run_logged env DEBUG=0 XDG_BIN_HOME="$BIN" bash "$upstream/bin/install.sh" --script-version "$ZWIFT_REV" --auto-confirm
    else
        [[ -f $BIN/zwift && -x $BIN/zwift ]] || die "Existing Zwift launcher is not executable: $BIN/zwift"
        say "Keeping existing $BIN/zwift"
    fi
    install_preserving "$ROOT/config/netbrain-zwift.conf" "$ZWIFT_CONFIG" 600

    if [[ ! -e $PREFIX/bin/qdomyos-zwift && ! -L $PREFIX/bin/qdomyos-zwift ]]; then
        local source="$PREFIX/source-$QZ_REV" build="$CACHE/qz-build-$QZ_REV"
        mkdir -p -- "$PREFIX" "$build"
        checkout_source https://github.com/cagnulein/qdomyos-zwift.git "$source" "$QZ_REV"
        run_logged git -C "$source" submodule update --init src/smtpclient
        if git -C "$source" apply --check --unidiff-zero "$ROOT/patches/qz-linux-user-permissions.patch"; then
            run_logged git -C "$source" apply --unidiff-zero "$ROOT/patches/qz-linux-user-permissions.patch"
        else
            git -C "$source" apply --reverse --check --unidiff-zero "$ROOT/patches/qz-linux-user-permissions.patch" || die 'QZ source does not match the expected patch.'
        fi
        (cd "$build"
            run_logged qmake "$source/src/qdomyos-zwift.pro" -after CONFIG-=ltcg CONFIG-=debug CONFIG+=release
            run_logged make "-j$JOBS"
            run_logged env QT_QPA_PLATFORM=offscreen ./qdomyos-zwift -smoke-test)
        install -Dm 644 "$source/LICENSE" "$PREFIX/LICENSE"
        install -Dm 644 "$source/src/icons/icon.png" "$PREFIX/icon.png"
        install -Dm 644 "$ROOT/patches/qz-linux-user-permissions.patch" "$PREFIX/patches/qz-linux-user-permissions.patch"
        install -Dm 755 "$build/qdomyos-zwift" "$PREFIX/bin/qdomyos-zwift.new"
        mv -- "$PREFIX/bin/qdomyos-zwift.new" "$PREFIX/bin/qdomyos-zwift"
    else
        [[ -f $PREFIX/bin/qdomyos-zwift && -x $PREFIX/bin/qdomyos-zwift ]] || die "Existing QZ binary is not executable: $PREFIX/bin/qdomyos-zwift"
        say "Keeping existing $PREFIX/bin/qdomyos-zwift"
    fi
    install_preserving "$ROOT/packaging/qz" "$BIN/qz" 755
    install_preserving "$ROOT/config/qdomyos-zwift.conf" "$QZ_CONFIG" 600
    say 'Software installation steps finished. Hardware and ride saving still need testing.'
    printf 'Next: follow README steps 2–4 for login, trainer pairing, ERG/SIM and a 3 km save test.\n'
    printf 'If existing files were preserved, compare the .zwift-linux-example files first.\n'
    printf 'For commands in this terminal: export PATH="$HOME/.local/bin:$PATH"\n'
    printf 'Log: %s\n' "$LOG"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi

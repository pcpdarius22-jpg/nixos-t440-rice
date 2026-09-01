#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'TXT'
ThinkPad T440 v12 RC7 clean NixOS installer

USAGE (from the NixOS 26.05 live ISO, booted in UEFI mode):
  sudo bash ./install-clean.sh --disk /dev/sdX
      DESTRUCTIVE: creates a 1 GiB EFI partition + ext4 root on the whole disk.

  sudo bash ./install-clean.sh --mounted
      SAFE FOR CUSTOM PARTITIONING: assumes your root is already mounted at
      /mnt and your EFI System Partition is mounted at /mnt/boot.

The installer generates hardware-configuration.nix from the actual mounted
machine. No UUID from another installation is ever reused.
TXT
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing command on live ISO: $1"; }

mode="${1:-}"
case "$mode" in
  -h|--help|'') usage; exit 0 ;;
esac

[ "${EUID:-$(id -u)}" -eq 0 ] || die 'run this installer with sudo/root'
[ -d /sys/firmware/efi ] || die 'live ISO is not booted in UEFI mode; reboot the ISO in UEFI mode (systemd-boot requires it)'

for c in nix nixos-generate-config nixos-install nixos-enter findmnt cp mkdir readlink grep tr; do need "$c"; done

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORK="$(mktemp -d /tmp/t440-v12-clean.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cp -a "$SRC_DIR"/. "$WORK"/
# A GitHub clone may carry its bootstrap .git/origin. The installed config must
# start as an independent machine-local repository so generated hardware data
# cannot accidentally be pushed and `nix-sync` cannot later diverge from the
# bootstrap remote.
rm -rf "$WORK/.git"

case "$mode" in
  --disk)
    DISK="${2:-}"
    [ -n "$DISK" ] || { usage; exit 2; }
    [ $# -eq 2 ] || { usage; exit 2; }
    [ -b "$DISK" ] || die "not a block device: $DISK"
    for c in lsblk parted wipefs mkfs.ext4 mkfs.fat partprobe udevadm mount umount swapoff; do need "$c"; done
    DISK="$(readlink -f -- "$DISK")"
    [ "$(lsblk -dn -o TYPE "$DISK" 2>/dev/null | tr -d '[:space:]')" = "disk" ]       || die "target must be a whole disk (for example /dev/sda or /dev/nvme0n1), not a partition: $DISK"
    [ "$(lsblk -dn -o RM "$DISK" 2>/dev/null | tr -d '[:space:]')" = "0" ]       || die "target is marked removable; this T440 whole-disk installer refuses removable media to reduce the chance of erasing the live USB"

    printf '\nTARGET DISK (EVERYTHING ON IT WILL BE ERASED):\n'
    lsblk -d -o NAME,SIZE,MODEL,TRAN,RM "$DISK" || true
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS "$DISK" || true
    printf '\nThis is intentionally destructive. The script does not guess the disk.\n'
    read -r -p "Type exactly: ERASE $DISK : " answer
    [ "$answer" = "ERASE $DISK" ] || die 'confirmation did not match; nothing erased'

    # Get the live install target out of the way if a previous attempt mounted it.
    if findmnt -M /mnt >/dev/null 2>&1; then umount -R /mnt || die 'could not unmount /mnt'; fi
    while read -r node; do
      [ "$node" = "$DISK" ] && continue
      swapoff "$node" >/dev/null 2>&1 || true
      while IFS= read -r target; do
        [ -n "$target" ] || continue
        umount -R "$target" >/dev/null 2>&1 || die "could not unmount $target from $node"
      done < <(findmnt -rn -S "$node" -o TARGET 2>/dev/null || true)
    done < <(lsblk -lnpo NAME "$DISK")

    # Refuse to continue if anything below the target is still mounted.
    if lsblk -nrpo MOUNTPOINTS "$DISK" | grep -q '[^[:space:]]'; then
      lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS "$DISK" >&2 || true
      die 'a target partition is still mounted; nothing has been erased'
    fi

    wipefs -af "$DISK"
    parted -s "$DISK" -- mklabel gpt
    parted -s "$DISK" -- mkpart ESP fat32 1MiB 1025MiB
    parted -s "$DISK" -- set 1 esp on
    parted -s "$DISK" -- mkpart nixos ext4 1025MiB 100%
    partprobe "$DISK" || true
    udevadm settle

    if [[ "$DISK" =~ [0-9]$ ]]; then
      ESP="${DISK}p1"; ROOT="${DISK}p2"
    else
      ESP="${DISK}1"; ROOT="${DISK}2"
    fi
    [ -b "$ESP" ] && [ -b "$ROOT" ] || die "expected partitions $ESP and $ROOT were not created"

    mkfs.fat -F 32 -n boot "$ESP"
    mkfs.ext4 -F -m 1 -L nixos "$ROOT"
    mount "$ROOT" /mnt
    mkdir -p /mnt/boot
    mount -o umask=077 "$ESP" /mnt/boot
    ;;

  --mounted)
    [ $# -eq 1 ] || { usage; exit 2; }
    findmnt -M /mnt >/dev/null 2>&1 || die '/mnt is not a mountpoint'
    findmnt -M /mnt/boot >/dev/null 2>&1 || die '/mnt/boot is not mounted (mount the EFI System Partition there)'
    ;;

  *) usage; die "unknown mode: $mode" ;;
esac

printf '\n[1/7] Generating THIS machine\x27s hardware/filesystem configuration...\n'
rm -rf /mnt/etc/nixos
nixos-generate-config --root /mnt
[ -s /mnt/etc/nixos/hardware-configuration.nix ] || die 'nixos-generate-config did not produce hardware-configuration.nix'
cp /mnt/etc/nixos/hardware-configuration.nix "$WORK/system/hardware-configuration.nix"

# Basic guard against accidentally retaining the clean-package placeholder.
if grep -Fq 'This clean-install package intentionally ships no disk UUIDs' "$WORK/system/hardware-configuration.nix"; then
  die 'hardware placeholder was not replaced'
fi

printf '[2/7] Checking the complete flake with the generated hardware config...\n'
nix --extra-experimental-features 'nix-command flakes' flake check "path:$WORK"

printf '[3/7] Installing NixOS 26.05 configuration...\n'
# Root remains locked; the normal user password is set interactively below.
nixos-install --no-root-passwd --flake "path:$WORK#thinkpad"

printf '[4/7] Installing the editable config at /etc/nixos...\n'
rm -rf /mnt/etc/nixos
mkdir -p /mnt/etc/nixos
cp -a "$WORK"/. /mnt/etc/nixos/
mkdir -p /mnt/home/sloth /mnt/home/sloth/Games /mnt/home/sloth/Pictures /mnt/home/sloth/Downloads /mnt/home/sloth/Music
ln -sfn /etc/nixos /mnt/home/sloth/nixos-config

printf '[5/7] Creating a local Git baseline for safe future experiments...\n'
# git is part of the installed system profile. The config stays local unless the
# user explicitly adds a remote later.
nixos-enter --root /mnt -c 'git -C /etc/nixos init -q && git -C /etc/nixos config user.name sloth && git -C /etc/nixos config user.email sloth@thinkpad.local && git -C /etc/nixos add -A && git -C /etc/nixos commit -qm "v12 RC7 clean-install baseline"'
nixos-enter --root /mnt -c 'chown -R sloth:users /etc/nixos /home/sloth'

printf '\n[6/7] Set the password for sloth (required for sudo/PolicyKit):\n'
nixos-enter --root /mnt -c 'passwd sloth'

printf '\n[7/7] Installation complete.\n'
printf 'Config: /etc/nixos (also available as ~/nixos-config)\n'
printf 'First boot: tty1 autologins as sloth and starts Sway.\n'
printf 'Rescue: touch ~/.disable-gui and restart Sway/tty1 to stay in text mode.\n'
printf 'After first login, run: rice-doctor\n'
printf 'Before experiments: nix-snapshot "before change"; test with nix-test; commit with nix-snapshot when happy.\n'
printf 'After first boot, run flatpak-bootstrap manually when you want RetroArch; no large Flatpak download starts automatically.\n\n'
printf 'You can now reboot.\n'

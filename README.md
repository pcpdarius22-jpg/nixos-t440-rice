# ThinkPad T440 — NixOS 26.05 Sway v12 RC7

Clean-install configuration for the 1600×900 ThinkPad T440 target.

RC7 is the painting-canvas revision: the bundled user-selected painting is
pre-cropped to exactly 1600×900; the host rice is only black/white/neutral gray;
known utility windows have no compositor borders and occupy authored free-space
zones around the painting's centre instead of appearing randomly.

## Target

- ThinkPad T440, i5-4300U / Intel HD 4400
- 12 GB RAM
- 1600×900 internal display
- UEFI
- user `sloth`
- NixOS 26.05 + Home Manager 26.05 pinned by `flake.lock`

The download intentionally contains a failing placeholder
`system/hardware-configuration.nix`. The installer replaces it with the target
machine's real generated configuration and runs a full `nix flake check` before
`nixos-install` is allowed to continue.

## Clean install

Boot the NixOS 26.05 live ISO in UEFI mode, enter this folder and identify the
internal SSD yourself with `lsblk`. For a whole-disk install:

```bash
sudo bash ./install-clean.sh --disk /dev/YOUR_DISK
```

The whole-disk path is destructive but guarded: it accepts a whole non-removable
disk only, prints it, requires the exact `ERASE /dev/...` confirmation, refuses
to wipe while a target partition remains mounted, then creates a 1 GiB ESP and
an ext4 root using the remainder.

For custom partitioning, mount root at `/mnt` and the ESP at `/mnt/boot`, then:

```bash
sudo bash ./install-clean.sh --mounted
```

After installation the editable config lives at `/etc/nixos` and
`~/nixos-config`. A fresh local Git baseline is created automatically; a GitHub
bootstrap clone/remote is deliberately stripped.

## First boot

tty1 auto-logs in once per boot and starts Sway. The first check is:

```bash
rice-doctor
```

RetroArch does **not** download during first login. When the base workstation is
confirmed good, run:

```bash
flatpak-bootstrap
```

## Workspace model

- **1 — canvas:** Foot, Yazi, Neovim, htop in authored corner zones
- **2 — web:** qutebrowser fullscreen
- **3 — studio:** REAPER fullscreen; plugin/dialog windows natural-size + centred
- **4 — media:** RetroArch, mpv, imv, Zathura fullscreen
- **5 — system:** nmtui, pulsemixer, Blueman, rice-fetch, optional qpwgraph

The centre/focal area of the painting is intentionally left visually open on
workspace 1. Coordinates scale from the T440's 1600×900 baseline if another
output is used.

## UI

The rice itself is strict grayscale. Terminal ANSI colors are mapped to gray;
htop uses monochrome mode. Wallpaper, web images/video, games, PDFs and other
real content are not recolored.

The Waybar layers remain transparent. Only the small top-left clock text block
and bottom-right workspace/battery/RAM text block have a solid black rectangle
under them—never a full-width bar.

## Audio

- 48 kHz
- 512-frame studio/default quantum
- 1024-frame safe/heavy-project fallback

`Super+R` launches REAPER at 512; `Super+Shift+R` uses 1024. The helper restores
the normal PipeWire graph when REAPER exits.

## Safe changes

```bash
nix-snapshot "before experiment"
nix-test
# use the temporary generation
nix-apply
nix-snapshot "keep experiment"
```

Use `nix-rollback` for a bad applied generation. If Sway itself is broken,
`touch ~/.disable-gui` keeps tty1 text-only on the next login. See
`CHANGE-SAFETY.md` for source-vs-generation rollback details.

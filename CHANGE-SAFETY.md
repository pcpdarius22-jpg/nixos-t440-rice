# Changing RC7 After Installation

The installed source lives at `/etc/nixos` and is linked as `~/nixos-config`.
The installer creates a fresh local Git baseline.

## Normal experiment loop

```bash
nix-snapshot "before changing something"
# edit files in ~/nixos-config
nix-test
```

`nix-test` runs the flake check, activates the new system/Home Manager generation
temporarily, then runs `rice-doctor`. A reboot returns to the previous boot
generation if you did not apply it.

When happy:

```bash
nix-apply
nix-snapshot "keep change"
```

Bad applied system generation:

```bash
nix-rollback
```

Important: Nix generation rollback does not rewrite your edited source files.
For uncommitted source edits you want to throw away:

```bash
cd ~/nixos-config
git status
git restore .
```

For committed source history, use normal Git history/revert, then `nix-test`.

## Where things live

- audio 512/1024 + optional qpwgraph: `rice-settings.nix`
- packages: `user/apps.nix`
- keybindings: `user/sway/config`
- workspace/placement map: `user/scripts/rice-window-placement`
- grayscale palette, bars, GTK, Fuzzel, qutebrowser chrome: `user/scripts/theme-sync`
- system power/Bluetooth/TLP/services: `system/configuration.nix`
- PipeWire defaults: `system/audio.nix`

## Wallpaper

No rebuild is needed:

```bash
set-wallpaper /path/to/image.jpg
```

or `Super+W`. Reset to the bundled painting with:

```bash
theme-sync --reset-reference
```

## Emergency rescue

If Sway is unusable:

```bash
touch ~/.disable-gui
```

Restart/log out/reboot. tty1 remains text-only. Repair or roll back, then:

```bash
rm ~/.disable-gui
```

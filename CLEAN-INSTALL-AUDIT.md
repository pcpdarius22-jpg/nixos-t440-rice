# v12 RC7 Pre-install Audit

RC7 carries forward RC5/RC6's installer, audio, rollback and monochrome fixes,
then replaces random placement with the painting-canvas workspace model.

## RC7-specific checks

- bundled wallpaper is exactly 1600×900
- host palette contains only neutral grayscale values
- Foot's ANSI 16-color palette is grayscale
- htop launches with `-C` monochrome mode and the interactive shell aliases it
- Waybar background is transparent; black exists only under clock/status blocks
- no Sway compositor borders/titlebars
- no random placement code remains
- workspace 1 utility slots are deterministic and scaled from 1600×900
- qutebrowser routes to workspace 2 fullscreen
- REAPER main routes to workspace 3 fullscreen
- REAPER/dialog/plugin windows retain natural size and centre instead of resize
- RetroArch/mpv/imv/Zathura route to workspace 4 fullscreen
- system utilities route to workspace 5
- unknown apps are not forced into guessed geometry
- cmus and tmux removed from the minimal base

## Existing safety checks retained

- destructive installer accepts a whole non-removable disk only
- exact erase confirmation required
- mounted-target guard before wipe
- real target `hardware-configuration.nix` generated before install
- real `nix flake check` must pass before `nixos-install`
- no bootstrap Git remote is copied into `/etc/nixos`
- local baseline created after install
- one-shot tty1 autologin only
- 5 systemd-boot entries / 8 system generations retained
- 25% zram; systemd-oomd disabled
- Haswell TLP policy uses schedutil with balanced energy policy
- PipeWire 48 kHz / 512 studio / 1024 safe helper tests
- first login does not automatically download Flatpak runtimes
- RetroArch Flatpak filesystem is narrowed to `~/Games`
- qutebrowser forced webpage dark filter disabled
- PDF recoloring disabled
- GTK/Fuzzel/Dunst/Waybar corner-radius checks

## Final evaluation boundary

The downloadable package intentionally cannot complete a real `nix flake check`
with its placeholder hardware file. On the live NixOS ISO, `install-clean.sh`
generates the T440 hardware/filesystem configuration, substitutes it into a
temporary copy, and runs the complete flake check **before** installation.

After first boot run `rice-doctor` for the remaining hardware/session checks:
actual Sway parsing, real app IDs, dual batteries, VA-API, PipeWire realtime
limits, Bluetooth, RetroArch/Flatpak portals and XRUN behavior at 512/1024.

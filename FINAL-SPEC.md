# v12 RC7 — Frozen Painting-Canvas Spec

## Identity

A sparse, borderless Sway workstation where the wallpaper is treated as the
painting/canvas and application windows are flat black content rectangles placed
around it.

Hard visual rules:

- host rice uses only black, white and neutral gray
- no Sway borders or titlebars
- square corners only
- no blur, shadows, glass, docks, dashboards or permanent window list
- no wallpaper-derived UI recoloring
- real content (painting, photos, video, games, PDFs, websites, DAW/plugin UI)
  remains in its original colors

## Wallpaper

The bundled user-selected painting is stored as an exact 1600×900 centre crop,
so `output * bg ... fill` requires no extra crop on the T440 panel. `Super+W` or
`set-wallpaper FILE` can replace it without rebuilding NixOS.

## Bars

Original sparse geometry:

- top-left: date/time only
- bottom-right: current workspace + weighted battery + RAM only
- 21 px transparent Waybar layers
- solid `#000000` background only under those two text blocks
- no full-width black strip

## Workspaces

1. **canvas** — Foot, Yazi, Neovim, htop in four authored free-space zones
2. **web** — qutebrowser fullscreen
3. **studio** — REAPER fullscreen; plugins/dialogs float at natural size centred
4. **media** — RetroArch, mpv, imv, Zathura fullscreen
5. **system** — nmtui, pulsemixer, Blueman, rice-fetch, optional qpwgraph

Placement is event-driven through one Sway IPC subscriber and contains no random
number generator or polling loop. Unknown apps are not forced into guessed
workspaces/sizes.

## Minimal applications

Core visual/workflow: Sway, Foot, Fuzzel, Waybar, Dunst, qutebrowser, Yazi,
Neovim, htop, pulsemixer, Blueman, Zathura, mpv, imv.

Production/compatibility: REAPER, Wine WoW64 stable, Winetricks, PipeWire /
WirePlumber, JACK compatibility.

Small helpers kept because they are wired into the workflow: cliphist,
wl-clipboard, fzf, fd, ripgrep, jq, grim/slurp, yt-dlp, udisks2 tools.

Not in the base profile: cmus, tmux, btop, fastfetch, senpai, Transmission,
Swappy, LocalSend, backup browser, giant widget shells. qpwgraph remains opt-in
through `rice-settings.nix`.

## Audio

- 48 kHz
- 512 studio/default quantum
- 1024 safe fallback
- RTKit + realtime/memlock limits
- 32-bit ALSA and JACK compatibility for Wine workflows
- HDA codec power saving disabled for workstation stability

## Recovery/change model

- `nix-test`: temporary generation + post-activation `rice-doctor`
- `nix-apply`: make tested source the boot generation + doctor
- `nix-rollback`: previous system generation
- `nix-snapshot`: local Git source checkpoint
- `~/.disable-gui`: tty rescue switch

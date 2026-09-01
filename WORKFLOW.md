# v12 RC7 Workflow

## Launches

| Shortcut | Result |
|---|---|
| `Super+Enter` | Foot → workspace 1, lower-left canvas slot |
| `Super+D` | Fuzzel launcher |
| `Super+Y` | Yazi → workspace 1, upper-left canvas slot |
| `Super+E` | Neovim → workspace 1, upper-right canvas slot |
| `Super+X` | monochrome htop → workspace 1, lower-right canvas slot |
| `Super+B` | qutebrowser → workspace 2 fullscreen |
| `Super+R` | REAPER → workspace 3 fullscreen, 512 frames |
| `Super+Shift+R` | REAPER → workspace 3 fullscreen, 1024 frames |
| `Super+Shift+W` | nmtui → workspace 5 |
| `Super+Shift+A` | pulsemixer → workspace 5 |
| `Super+Shift+B` | Blueman → workspace 5 |
| `Super+Shift+F` | rice-fetch → workspace 5 |
| `Super+W` | wallpaper picker |

RetroArch is installed only when `flatpak-bootstrap` is run manually. RetroArch,
mpv, imv and Zathura are routed to workspace 4 fullscreen.

## Workspace keys

`Super+1..5` changes workspace. `Super+Shift+1..5` sends the focused window to a
workspace. The bottom-right status shows only the current workspace number,
battery and RAM; there is no persistent workspace strip.

## Canvas behavior

Workspace 1 is intentionally art-directed rather than tiled or randomized:

- Yazi: upper-left
- Neovim: upper-right
- Foot: lower-left
- htop: lower-right

Those rectangles are authored around the painting's central figure/table/chair
area. They have no Sway border/titlebar. Reopening the same app uses the same
slot rather than changing the composition.

Unknown applications are not shoved into guessed geometry. Dialogs and DAW
plugin windows preserve their requested size and are centred.

## Sparse / Plan-9-inspired actions

- `Super+P` — plumb selection/clipboard to the appropriate app
- `Super+O` — on-demand window picker
- `Super+V` — clipboard history picker
- `Super+Shift+-` — hide focused window to scratchpad
- `Super+-` — show/cycle scratchpad

## Manual overrides

- `Super+F` fullscreen toggle
- `Super+Space` floating toggle
- `Super+C` centre floating window
- `Super+Shift+C` move floating window to pointer
- `Super+mouse` direct move/resize
- `Super+Q` close
- `Super+Tab` / `Super+Shift+Tab` next/previous

## DAW passthrough

`Super+F12` or `Super+Pause` enters passthrough mode so normal compositor
shortcuts stop stealing keys from the focused DAW. Exit with either key again or
`Super+Escape`.

## Audio helpers

```bash
audio-lowlatency   # configured studio mode: 512
audio-safe         # 1024
audio-normal       # clear forced quantum
reaper-pw          # configured 512
RICE_AUDIO_QUANTUM=1024 reaper-pw
```

## Removable media

No GUI automounter runs continuously. Use udisks2 on demand:

```bash
udisksctl mount -b /dev/sdX1
udisksctl unmount -b /dev/sdX1
```

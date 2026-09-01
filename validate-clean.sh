#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
fail=0
ok(){ printf 'OK   %s\n' "$1"; }
bad(){ printf 'FAIL %s\n' "$1"; fail=1; }
info(){ printf 'INFO %s\n' "$1"; }

printf 'v12 RC7 pre-install static/regression validation\n\n'

printf 'Shell syntax\n'
for f in "$ROOT/install-clean.sh" "$ROOT/validate-clean.sh" "$ROOT/user/scripts/"*; do
  if bash -n "$f"; then ok "bash: ${f#$ROOT/}"; else bad "bash: ${f#$ROOT/}"; fi
done

printf '\nClean-install safety\n'
grep -Fq 'system.stateVersion = "26.05"' "$ROOT/system/configuration.nix" && ok 'system stateVersion 26.05' || bad 'system stateVersion'
grep -Fq 'home.stateVersion = "26.05"' "$ROOT/user/home.nix" && ok 'home stateVersion 26.05' || bad 'home stateVersion'
grep -Fq 'This clean-install package intentionally ships no disk UUIDs' "$ROOT/system/hardware-configuration.nix" && ok 'hardware config is deliberate failing placeholder' || bad 'hardware placeholder'
grep -Fq 'flake check "path:$WORK"' "$ROOT/install-clean.sh" && ok 'real flake check happens before installation' || bad 'pre-install flake check'
grep -Fq 'target must be a whole disk' "$ROOT/install-clean.sh" && grep -Fq 'lsblk -dn -o TYPE' "$ROOT/install-clean.sh" && ok 'whole-disk target type guard' || bad 'whole-disk guard'
grep -Fq 'target is marked removable' "$ROOT/install-clean.sh" && ok 'removable/live-USB erase guard' || bad 'removable-media guard'
grep -Fq "mkfs.ext4 -F -m 1" "$ROOT/install-clean.sh" && ok 'ext4 root reserves 1%, not wasteful default 5%' || bad 'ext4 reserved-block setting'
grep -Fq 'rm -rf "$WORK/.git"' "$ROOT/install-clean.sh" && ok 'bootstrap Git remote stripped before local baseline' || bad 'Git bootstrap isolation'
grep -Fq 'v12 RC7 clean-install baseline' "$ROOT/install-clean.sh" && ok 'local Git baseline created' || bad 'Git baseline'
grep -Fq 'services.getty.autologinOnce = true;' "$ROOT/system/configuration.nix" && ok 'tty autologin limited to first tty/once per boot' || bad 'autologinOnce'
grep -Fq 'configurationLimit = 5;' "$ROOT/system/configuration.nix" && ok 'five visible boot generations' || bad 'boot generation limit'
grep -Fq -- '--delete-generations +8' "$ROOT/system/configuration.nix" && ok 'eight system generations retained before GC' || bad 'generation retention'

printf '\nPerformance / resource policy\n'
grep -Fq 'systemd.oomd.enable = false;' "$ROOT/system/configuration.nix" && ok 'unused systemd-oomd daemon disabled' || bad 'oomd policy'
grep -Fq 'CPU_SCALING_GOVERNOR_ON_AC = "schedutil";' "$ROOT/system/configuration.nix" \
  && grep -Fq 'CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";' "$ROOT/system/configuration.nix" \
  && ok 'Haswell governor uses schedutil' || bad 'CPU governor'
grep -Fq 'CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";' "$ROOT/system/configuration.nix" \
  && grep -Fq 'CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";' "$ROOT/system/configuration.nix" \
  && ok 'balanced Intel energy policy' || bad 'CPU energy policy'
if grep -Eq 'sansSerif[[:space:]]*=|serif[[:space:]]*=' "$ROOT/system/configuration.nix" "$ROOT/user/home.nix"; then
  bad 'bitmap font still overrides generic serif/sans'
else
  ok 'bitmap font limited to monospace/UI use'
fi
grep -Fq 'zramSwap' "$ROOT/system/configuration.nix" && grep -Fq 'memoryPercent = 25;' "$ROOT/system/configuration.nix" && ok 'modest 25% zram safety net' || bad 'zram'
! grep -Fq 'libvdpau-va-gl' "$ROOT/system/configuration.nix" && ok 'unused VDPAU bridge removed' || bad 'unused VDPAU bridge remains'

printf '\nAudio profile\n'
grep -Fq 'studioQuantum = 512;' "$ROOT/rice-settings.nix" && ok 'studio quantum 512' || bad 'studio quantum'
grep -Fq 'safeQuantum = 1024;' "$ROOT/rice-settings.nix" && ok 'safe quantum 1024' || bad 'safe quantum'
grep -Fq '"default.clock.quantum" = studio;' "$ROOT/system/audio.nix" && ok 'PipeWire default follows studio setting' || bad 'PipeWire default quantum'
grep -Fq 'alsa.support32Bit = true;' "$ROOT/system/audio.nix" && grep -Fq 'jack.enable = true;' "$ROOT/system/audio.nix" && ok '32-bit ALSA + JACK compatibility present' || bad 'audio compatibility'

# Runtime helper test with fake PipeWire/REAPER executables. Invoke through bash
# so validation remains valid even after browser/GitHub ZIP transport strips x bits.
TMPA="$(mktemp -d)"
trap 'rm -rf "$TMPA" "${TMPP:-}" "${TMPT:-}"' EXIT
mkdir -p "$TMPA/.config/rice" "$TMPA/bin"
cat > "$TMPA/.config/rice/audio.env" <<AUDIO
RICE_AUDIO_RATE=48000
RICE_STUDIO_QUANTUM=512
RICE_SAFE_QUANTUM=1024
AUDIO
cat > "$TMPA/bin/pw-metadata" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${RICE_TEST_LOG:?}"
SH
cat > "$TMPA/bin/reaper" <<'SH'
#!/usr/bin/env bash
printf 'latency=%s\n' "${PIPEWIRE_LATENCY:-}" >> "${RICE_TEST_LOG:?}"
SH
cat > "$TMPA/bin/notify-send" <<'SH'
#!/usr/bin/env bash
:
SH
chmod +x "$TMPA/bin/"*
RICE_TEST_LOG="$TMPA/log" HOME="$TMPA" XDG_CONFIG_HOME="$TMPA/.config" PATH="$TMPA/bin:$PATH" \
  bash "$ROOT/user/scripts/reaper-pw"
if grep -Fq 'clock.force-quantum 512' "$TMPA/log" \
   && grep -Fq 'latency=512/48000' "$TMPA/log" \
   && tail -1 "$TMPA/log" | grep -Fq 'clock.force-quantum 0'; then
  ok 'reaper-pw forces 512 and restores graph'
else
  bad 'reaper-pw 512 behavior'
fi
: > "$TMPA/log"
RICE_TEST_LOG="$TMPA/log" HOME="$TMPA" XDG_CONFIG_HOME="$TMPA/.config" PATH="$TMPA/bin:$PATH" RICE_AUDIO_QUANTUM=1024 \
  bash "$ROOT/user/scripts/reaper-pw"
if grep -Fq 'clock.force-quantum 1024' "$TMPA/log" && grep -Fq 'latency=1024/48000' "$TMPA/log"; then
  ok 'reaper-pw 1024 fallback'
else
  bad 'reaper-pw 1024 behavior'
fi

printf '\nMinimal application profile / sandboxing\n'
for wanted in cliphist htop yazi; do
  grep -Eq "^[[:space:]]+$wanted$" "$ROOT/user/apps.nix" && ok "default: $wanted" || bad "missing default: $wanted"
done
grep -Fq 'lib.optionals rice.optionalApps.qpwgraph' "$ROOT/user/apps.nix" && ok 'qpwgraph remains opt-in' || bad 'qpwgraph toggle'
for unwanted in cmus btop senpai transmission_4 tremc fastfetch lazygit lynx zoxide sox swappy; do
  if grep -Eq "^[[:space:]]+$unwanted$" "$ROOT/user/apps.nix"; then bad "unnecessary default: $unwanted"; else ok "not default: $unwanted"; fi
done
if grep -Fq 'com.github.tchx84.Flatseal' "$ROOT/user/scripts/flatpak-bootstrap"; then
  bad 'Flatseal still preinstalled'
else
  ok 'Flatseal not preinstalled'
fi
if grep -Fq 'exec flatpak-bootstrap' "$ROOT/user/sway/config"; then
  bad 'first login still starts Flatpak downloads automatically'
else
  ok 'RetroArch bootstrap is manual; no first-login background download'
fi
if grep -Fq 'xdg-config/gtk-' "$ROOT/user/scripts/flatpak-bootstrap"; then
  bad 'global Flatpak GTK config permission remains'
else
  ok 'no global GTK filesystem permission for Flatpaks'
fi
grep -Fq 'org.libretro.RetroArch' "$ROOT/user/scripts/flatpak-bootstrap" \
  && grep -Fq -- '--nofilesystem=host' "$ROOT/user/scripts/flatpak-bootstrap" \
  && grep -Fq 'Games:create' "$ROOT/user/scripts/flatpak-bootstrap" \
  && ok 'RetroArch sandbox narrowed to Games directory' || bad 'RetroArch override'

printf '\nWindow/workspace policy\n'
grep -Fq 'dwt disabled' "$ROOT/user/sway/config" && ok 'touchpad DWT disabled for DAW input' || bad 'touchpad DWT'
if grep -Fq 'RANDOM' "$ROOT/user/scripts/rice-window-placement"; then bad 'random placement logic remains'; else ok 'placement is deterministic, not random'; fi
grep -Fq 'systemd.user.services.rice-window-placement' "$ROOT/system/configuration.nix" && ok 'placement service supervised' || bad 'placement service'
grep -Fq 'Main content apps use dedicated workspaces' "$ROOT/user/sway/config" && ok 'workspace model documented in Sway config' || bad 'workspace model comment'
grep -Fq 'htop -C' "$ROOT/user/sway/config" && ok 'htop launcher is monochrome' || bad 'htop monochrome launcher'
if grep -Eq '^[[:space:]]*programs\.tmux[[:space:]]*=' "$ROOT/user/home.nix"; then bad 'unused tmux still enabled'; else ok 'tmux removed from minimal base'; fi

TMPP="$(mktemp -d)"
cat > "$TMPP/swaymsg" <<'SH'
#!/usr/bin/env bash
set -e
if [[ "$*" == *"get_tree"* ]]; then
  case "${RICE_TEST_KIND:-utility}" in
    utility) echo '{"id":1,"type":"root","nodes":[{"id":42,"type":"con","app_id":"editor","name":"nvim","rect":{"width":620,"height":470},"window_properties":{}}]}' ;;
    main) echo '{"id":1,"type":"root","nodes":[{"id":43,"type":"con","app_id":"qutebrowser","name":"qutebrowser","rect":{"width":1200,"height":800},"window_properties":{}}]}' ;;
    plugin) echo '{"id":1,"type":"root","nodes":[{"id":44,"type":"con","app_id":"","name":"ReaEQ","rect":{"width":507,"height":392},"window_properties":{"class":"REAPER","window_type":"dialog","transient_for":45}}]}' ;;
    reaper) echo '{"id":1,"type":"root","nodes":[{"id":45,"type":"con","app_id":"","name":"song.rpp - REAPER v7.20","rect":{"width":1200,"height":800},"window_properties":{"class":"REAPER"}}]}' ;;
    media) echo '{"id":1,"type":"root","nodes":[{"id":46,"type":"con","app_id":"org.pwmt.zathura","name":"manual.pdf","rect":{"width":900,"height":700},"window_properties":{}}]}' ;;
    system) echo '{"id":1,"type":"root","nodes":[{"id":47,"type":"con","app_id":"nmtui","name":"network","rect":{"width":500,"height":300},"window_properties":{}}]}' ;;
    unknown) echo '{"id":1,"type":"root","nodes":[{"id":48,"type":"con","app_id":"mystery","name":"mystery","rect":{"width":500,"height":300},"window_properties":{}}]}' ;;
  esac
elif [[ "$*" == *"get_outputs"* ]]; then
  echo '[{"focused":true,"rect":{"x":0,"y":0,"width":1600,"height":900}}]'
else
  printf '%s\n' "$*" >> "${RICE_TEST_LOG:?}"
fi
SH
chmod +x "$TMPP/swaymsg"
export RICE_TEST_LOG="$TMPP/log"
RICE_TEST_KIND=utility PATH="$TMPP:$PATH" bash "$ROOT/user/scripts/rice-window-placement" --place-id 42
if grep -Fq '[con_id=42] move container to workspace number 1, floating enable, border none, resize set 510 350, move position 1010 90' "$TMPP/log" \
   && grep -Fq 'workspace number 1' "$TMPP/log"; then
  ok 'editor uses deterministic upper-right canvas slot on workspace 1'
else
  bad 'editor canvas placement'
fi
: > "$TMPP/log"
RICE_TEST_KIND=main PATH="$TMPP:$PATH" bash "$ROOT/user/scripts/rice-window-placement" --place-id 43
if grep -Fq 'move container to workspace number 2, floating disable, border none, fullscreen enable' "$TMPP/log" \
   && grep -Fq 'workspace number 2' "$TMPP/log"; then ok 'qutebrowser -> workspace 2 fullscreen'; else bad 'qutebrowser workspace policy'; fi
: > "$TMPP/log"
RICE_TEST_KIND=plugin PATH="$TMPP:$PATH" bash "$ROOT/user/scripts/rice-window-placement" --place-id 44
if grep -Fq '[con_id=44] floating enable, border none, move position center' "$TMPP/log" \
   && ! grep -Fq 'resize set' "$TMPP/log" \
   && ! grep -Fq 'fullscreen enable' "$TMPP/log"; then
  ok 'REAPER plugin keeps natural size and centers'
else
  bad 'REAPER plugin/dialog preservation'
fi
: > "$TMPP/log"
RICE_TEST_KIND=reaper PATH="$TMPP:$PATH" bash "$ROOT/user/scripts/rice-window-placement" --place-id 45
if grep -Fq 'move container to workspace number 3, floating disable, border none, fullscreen enable' "$TMPP/log"; then ok 'REAPER main -> workspace 3 fullscreen'; else bad 'REAPER main workspace policy'; fi
: > "$TMPP/log"
RICE_TEST_KIND=media PATH="$TMPP:$PATH" bash "$ROOT/user/scripts/rice-window-placement" --place-id 46
if grep -Fq 'move container to workspace number 4, floating disable, border none, fullscreen enable' "$TMPP/log"; then ok 'media/document -> workspace 4 fullscreen'; else bad 'media workspace policy'; fi
: > "$TMPP/log"
RICE_TEST_KIND=system PATH="$TMPP:$PATH" bash "$ROOT/user/scripts/rice-window-placement" --place-id 47
if grep -Fq '[con_id=47] move container to workspace number 5, floating enable, border none, resize set 560 360, move position 80 120' "$TMPP/log"; then ok 'system tool -> workspace 5 authored slot'; else bad 'system workspace policy'; fi
: > "$TMPP/log"
RICE_TEST_KIND=unknown PATH="$TMPP:$PATH" bash "$ROOT/user/scripts/rice-window-placement" --place-id 48
if grep -Fq '[con_id=48] border none' "$TMPP/log" && ! grep -Eq 'resize set|move container to workspace|fullscreen enable' "$TMPP/log"; then ok 'unknown app is not forced into guessed geometry/workspace'; else bad 'unknown-app preservation'; fi

printf '\nTheme / browser media / bars\n'
grep -Fq 'colors.webpage.darkmode.enabled = false' "$ROOT/user/apps.nix" && ok 'qutebrowser forced dark renderer disabled' || bad 'qutebrowser darkmode'
grep -Fq 'set recolor false' "$ROOT/user/scripts/theme-sync" && ok 'PDF content recoloring disabled' || bad 'PDF recolor'
grep -Fq '[border]' "$ROOT/user/scripts/theme-sync" && grep -Fq 'selection-radius=0' "$ROOT/user/scripts/theme-sync" && ok 'Fuzzel square border syntax' || bad 'Fuzzel square config'
if grep -Fq 'BG="#000000"' "$ROOT/user/scripts/theme-sync" \
   && grep -Fq 'FG="#e8e8e8"' "$ROOT/user/scripts/theme-sync" \
   && grep -Fq 'SEL="#303030"' "$ROOT/user/scripts/theme-sync"; then
  ok 'strict grayscale palette'
else
  bad 'monochrome palette'
fi
if python3 - "$ROOT/user/wallpaper/reference.png" >/dev/null 2>&1 <<'PYP'
import struct, sys
p=sys.argv[1]
with open(p,'rb') as f:
    sig=f.read(24)
if sig[:8] != b'\x89PNG\r\n\x1a\n':
    raise SystemExit(1)
w,h=struct.unpack('>II',sig[16:24])
if (w,h)!=(1600,900):
    raise SystemExit(2)
PYP
then
  ok 'bundled painting is pre-cropped exactly to 1600x900'
else
  bad 'reference wallpaper is not exact 1600x900 PNG'
fi
if python3 - "$ROOT/user/scripts/theme-sync" "$ROOT/user/apps.nix" >/dev/null 2>&1 <<'PYGRAY'
import re, sys
for name in sys.argv[1:]:
    text=open(name, encoding='utf-8').read()
    for h in re.findall(r'#[0-9A-Fa-f]{6}', text):
        r,g,b=int(h[1:3],16),int(h[3:5],16),int(h[5:7],16)
        if not (r == g == b):
            raise SystemExit(f'non-grayscale color {h} in {name}')
PYGRAY
then
  ok 'host UI source contains no non-grayscale hex colors'
else
  bad 'non-grayscale host UI color remains'
fi
if grep -Fq 'OLD_SEED' "$ROOT/user/scripts/theme-sync" || grep -Fq 'v11.3.3' "$ROOT/user/scripts/theme-sync"; then bad 'stale migration code remains'; else ok 'clean-install theme has no stale migration path'; fi

TMPT="$(mktemp -d)"
mkdir -p "$TMPT/.config/rice/reference"
cp "$ROOT/user/wallpaper/reference.png" "$TMPT/.config/rice/reference/reference.png"
HOME="$TMPT" XDG_CONFIG_HOME="$TMPT/.config" XDG_CACHE_HOME="$TMPT/.cache" XDG_DATA_HOME="$TMPT/.local/share" \
  RICE_REFERENCE_WALLPAPER="$ROOT/user/wallpaper/reference.png" \
  bash "$ROOT/user/scripts/theme-sync" --startup >/dev/null
jq -e . "$TMPT/.config/rice/waybar/config.json" >/dev/null && ok 'generated Waybar JSON parses' || bad 'Waybar JSON'
if jq -e 'length==2 and .[0]["modules-left"]==["clock"] and (.[0]["modules-right"]//[])==[] and .[1]["modules-right"]==["custom/rice-status"] and (.[1]["modules-left"]//[])==[]' "$TMPT/.config/rice/waybar/config.json" >/dev/null; then
  ok 'bars remain clock only + workspace/battery/RAM only'
else
  bad 'bar gained extra modules'
fi
if grep -Fq '#clock, #custom-rice-status {' "$TMPT/.config/rice/waybar/style.css" \
   && grep -Fq 'background: #000000;' "$TMPT/.config/rice/waybar/style.css" \
   && grep -Fq 'window#waybar {' "$TMPT/.config/rice/waybar/style.css" \
   && grep -Fq 'background: transparent;' "$TMPT/.config/rice/waybar/style.css"; then
  ok 'black underlay exists only on clock/status text blocks'
else
  bad 'bar text-underlay geometry'
fi
python3 - <<PY >/dev/null 2>&1 && ok 'generated Yazi TOML parses' || bad 'Yazi TOML'
import tomllib
from pathlib import Path
tomllib.loads(Path("$TMPT/.config/rice/yazi/theme.toml").read_text())
PY
awk '/^\[border\]$/{b=1;next}/^\[/{b=0} b&&/^radius=0$/{r=1} b&&/^selection-radius=0$/{s=1} END{exit !(r&&s)}' "$TMPT/.config/rice/generated/fuzzel.ini" \
  && ok 'Fuzzel radius zero' || bad 'Fuzzel radius'
! grep -Eiq 'filter[[:space:]]*:|grayscale\(|invert\(' "$TMPT/.config/rice/generated/web.css" && ok 'web media CSS has no recolor filters' || bad 'web CSS filter'
grep -Fq 'border-radius: 0' "$TMPT/.config/gtk-3.0/gtk.css" && grep -Fq 'border-radius: 0' "$TMPT/.config/gtk-4.0/gtk.css" \
  && ok 'GTK3/4 square CSS' || bad 'GTK square CSS'

printf '\nChange / rollback workflow\n'
grep -Fq 'nixos-rebuild test' "$ROOT/user/scripts/nix-test" && grep -Fq 'rice-doctor' "$ROOT/user/scripts/nix-test" && ok 'nix-test activates temporary generation then checks it' || bad 'nix-test'
grep -Fq 'nixos-rebuild switch' "$ROOT/user/scripts/nix-apply" \
  && awk '/nixos-rebuild switch/{s=NR}/rice-doctor/{d=NR} END{exit !(s && d && d>s)}' "$ROOT/user/scripts/nix-apply" \
  && ok 'nix-apply checks after switch' || bad 'nix-apply order'
grep -Fq 'switch --rollback' "$ROOT/user/scripts/nix-rollback" && ok 'generation rollback helper' || bad 'nix-rollback'
grep -Fq 'git commit' "$ROOT/user/scripts/nix-snapshot" && ok 'source checkpoint helper' || bad 'nix-snapshot'

if command -v nix >/dev/null 2>&1 && ! grep -Fq 'assertion = false;' "$ROOT/system/hardware-configuration.nix"; then
  nix --extra-experimental-features 'nix-command flakes' flake check "path:$ROOT" && ok 'nix flake check' || bad 'nix flake check'
else
  info 'Full Nix evaluation is intentionally deferred: the download ships an invalid hardware placeholder. install-clean.sh replaces it with the target T440 config and runs nix flake check before nixos-install.'
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
  printf 'ALL AVAILABLE STATIC/HELPER TESTS PASSED\n'
else
  printf 'VALIDATION FAILED\n'
fi
exit "$fail"

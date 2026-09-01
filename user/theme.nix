{ config, lib, pkgs, ... }:
let
  rice = import ../rice-settings.nix;
  runtimePath = lib.makeBinPath (with pkgs; [
    bash coreutils gnugrep gnused findutils jq imagemagick
    sway systemd dunst foot procps fuzzel python3 fontconfig waybar
    wl-clipboard cliphist
  ]);
in
{
  home.file.".config/rice/reference/reference.png".source = ./wallpaper/reference.png;
  home.file.".config/rice/reference/WALLPAPER-LICENSE.txt".source = ./wallpaper/WALLPAPER-LICENSE.txt;
  home.file.".config/sway/config".source = ./sway/config;

  # Shell helpers. These are plain text files in the repo on purpose: changing
  # behavior later means editing a small script, not rebuilding a custom binary.
  home.file.".local/bin/theme-sync" = { source = ./scripts/theme-sync; executable = true; };
  home.file.".local/bin/set-wallpaper" = { source = ./scripts/set-wallpaper; executable = true; };
  home.file.".local/bin/wallpaper-menu" = { source = ./scripts/wallpaper-menu; executable = true; };
  home.file.".local/bin/rice-status" = { source = ./scripts/rice-status; executable = true; };
  home.file.".local/bin/rice-session" = { source = ./scripts/rice-session; executable = true; };
  home.file.".local/bin/rice-foot" = { source = ./scripts/rice-foot; executable = true; };
  home.file.".local/bin/rice-fetch" = { source = ./scripts/rice-fetch; executable = true; };
  home.file.".local/bin/rice-yazi" = { source = ./scripts/rice-yazi; executable = true; };
  home.file.".local/bin/audio-lowlatency" = { source = ./scripts/audio-lowlatency; executable = true; };
  home.file.".local/bin/audio-safe" = { source = ./scripts/audio-safe; executable = true; };
  home.file.".local/bin/audio-normal" = { source = ./scripts/audio-normal; executable = true; };
  home.file.".local/bin/reaper-pw" = { source = ./scripts/reaper-pw; executable = true; };
  home.file.".local/bin/rice-doctor" = { source = ./scripts/rice-doctor; executable = true; };
  home.file.".local/bin/rice-check" = { source = ./scripts/rice-check; executable = true; };
  home.file.".local/bin/nix-sync" = { source = ./scripts/nix-sync; executable = true; };
  home.file.".local/bin/nix-test" = { source = ./scripts/nix-test; executable = true; };
  home.file.".local/bin/nix-apply" = { source = ./scripts/nix-apply; executable = true; };
  home.file.".local/bin/nix-rollback" = { source = ./scripts/nix-rollback; executable = true; };
  home.file.".local/bin/nix-snapshot" = { source = ./scripts/nix-snapshot; executable = true; };

  # v12 desktop plumbing/helpers.
  home.file.".local/bin/flatpak-bootstrap" = { source = ./scripts/flatpak-bootstrap; executable = true; };
  home.file.".local/bin/rice-polkit-agent" = { source = ./scripts/rice-polkit-agent; executable = true; };
  home.file.".local/bin/rice-plumb" = { source = ./scripts/rice-plumb; executable = true; };
  home.file.".local/bin/rice-windows" = { source = ./scripts/rice-windows; executable = true; };
  home.file.".local/bin/rice-window-placement" = { source = ./scripts/rice-window-placement; executable = true; };
  home.file.".local/bin/rice-clipboard" = { source = ./scripts/rice-clipboard; executable = true; };

  # Keep audio tuning in one obvious source file (`rice-settings.nix`) and emit
  # a tiny shell-readable copy for runtime helpers.
  home.file.".config/rice/audio.env".text = ''
    RICE_AUDIO_RATE=${toString rice.audio.rate}
    RICE_STUDIO_QUANTUM=${toString rice.audio.studioQuantum}
    RICE_SAFE_QUANTUM=${toString rice.audio.safeQuantum}
  '';

  # Generate the fixed square UI files during activation. Wallpaper and browser
  # media stay full-color and independent from UI colors.
  home.activation.generateRiceTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export HOME=${lib.escapeShellArg config.home.homeDirectory}
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_DATA_HOME="$HOME/.local/share"
    export PATH=${lib.escapeShellArg runtimePath}:$PATH
    export RICE_REFERENCE_WALLPAPER=${lib.escapeShellArg (toString ./wallpaper/reference.png)}
    ${pkgs.bash}/bin/bash ${./scripts/theme-sync} --activation
  '';
}

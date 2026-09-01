{ pkgs, lib, ... }:
let
  rice = import ../rice-settings.nix;
in
{
  home.packages = with pkgs; [
    # Core rice stack
    foot
    waybar
    fuzzel
    imagemagick
    wireplumber
    pipewire
    libnotify
    blueman

    # Wayland/Sway utilities
    swayidle
    swaylock
    grim
    slurp
    wl-clipboard
    cliphist
    brightnessctl
    playerctl

    # Terminal-first daily tools. Avoid duplicate GUI utilities and tools that
    # are not wired into the workflow.
    yazi
    htop
    fzf
    fd
    ripgrep
    jq
    gawk
    fontconfig
    file
    pulsemixer
    socat
    procps
    python3

    # Lightweight viewers / media
    imv
    zathura
    yt-dlp

    # Music production / Windows compatibility stay native for direct
    # PipeWire/JACK/realtime and device access.
    reaper
    wineWow64Packages.stable
    winetricks

    # RetroArch intentionally lives on Flathub so cores/assets can be managed
    # inside RetroArch instead of rebuilding NixOS.
  ] ++ lib.optionals rice.optionalApps.qpwgraph [
    pkgs.qpwgraph
  ];

  programs.qutebrowser = {
    enable = true;
    loadAutoconfig = false;
    keyBindings.normal = {
      "d" = "tab-close";
      "u" = "undo";
      ",m" = "spawn mpv {url}";
      ",y" = "spawn yt-dlp {url}";
    };
    searchEngines = {
      DEFAULT = "https://duckduckgo.com/?q={}";
      nw = "https://wiki.nixos.org/index.php?search={}";
      aw = "https://wiki.archlinux.org/?search={}";
    };
    settings = {
      tabs.position = "right";
      tabs.width = 30;
      tabs.title.alignment = "center";
      tabs.favicons.show = "never";
      tabs.indicator.width = 0;
      tabs.title.format = "{index}";
      tabs.show = "multiple";

      statusbar.show = "in-mode";
      statusbar.position = "bottom";

      fonts.default_family = "PxPlus IBM VGA 8x16";
      fonts.default_size = "10pt";
      fonts.statusbar = "10pt PxPlus IBM VGA 8x16";
      fonts.tabs.selected = "10pt PxPlus IBM VGA 8x16";
      fonts.tabs.unselected = "10pt PxPlus IBM VGA 8x16";
      fonts.completion.entry = "10pt PxPlus IBM VGA 8x16";
      fonts.completion.category = "bold 10pt PxPlus IBM VGA 8x16";

      content.javascript.enabled = true;
      content.blocking.enabled = true;
      content.blocking.method = "auto";
      content.notifications.presenter = "libnotify";

      # Monochrome browser chrome, untouched web media. This is the fix for the
      # old grayscale YouTube/images behavior.
      colors.webpage.darkmode.enabled = false;
      colors.webpage.preferred_color_scheme = "dark";
      colors.webpage.bg = "#000000";

      scrolling.bar = "never";
      hints.radius = 0;
      tabs.tooltips = false;
      window.hide_decoration = true;
      url.start_pages = [ "about:blank" ];
      url.default_page = "about:blank";

      editor.command = [ "rice-foot" "-a" "qute-editor" "nvim" "+call cursor({line}, {column})" "{file}" ];
    };
    extraConfig = ''
      c.tabs.padding = {
          'top': 4,
          'bottom': 4,
          'left': 8,
          'right': 6,
      }
      c.statusbar.padding = {
          'top': 5,
          'bottom': 5,
          'left': 8,
          'right': 8,
      }

      import os
      _rice_theme = os.path.expanduser('~/.config/rice/generated/qute-colors.py')
      if os.path.isfile(_rice_theme):
          config.source(_rice_theme)
      _rice_web = os.path.expanduser('~/.config/rice/generated/web.css')
      if os.path.isfile(_rice_web):
          c.content.user_stylesheets = [_rice_web]
    '';
  };

  services.dunst = {
    enable = true;
    configFile = "/home/sloth/.config/rice/generated/dunstrc";
  };

}

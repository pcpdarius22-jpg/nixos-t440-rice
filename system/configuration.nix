{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Conservative, recoverable boot path. Keep several known-good entries.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
    editor = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "threadirqs"
    # Music workstation: avoid HDA codec sleep/wake latency and click/pop risk.
    "snd_hda_intel.power_save=0"
  ];

  networking.hostName = "thinkpad";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  # ThinkPad T440: Haswell i5-4300U + Intel HD 4400.
  environment.variables.LIBVA_DRIVER_NAME = "i965";
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
    ];
  };

  # 12 GB RAM: a modest zram-only safety net for the clean install.
  # 25% caps zram at ~3 GB; the default clean layout intentionally has no disk swap.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # For a DAW workstation prefer the kernel OOM path + zram over a second
  # userspace OOM daemon. In this pinned NixOS release systemd-oomd is enabled
  # by default even when no ManagedOOM slices are selected.
  systemd.oomd.enable = false;

  # Keep enough rollback history for experimentation without letting generations
  # grow forever. configurationLimit below only controls visible boot entries.
  systemd.services.nixos-generation-trimmer = {
    description = "Trim old NixOS system generations";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +8 || true
      ${pkgs.nix}/bin/nix-collect-garbage
    '';
  };
  systemd.timers.nixos-generation-trimmer = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  services.tlp = {
    enable = true;
    settings = {
      # Haswell (5th gen or older behavior in modern kernels) uses intel_pstate
      # passive/intel_cpufreq. schedutil avoids the sluggish passive-driver
      # powersave governor while not pinning the CPU at performance all day.
      CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
      START_CHARGE_THRESH_BAT1 = 40;
      STOP_CHARGE_THRESH_BAT1 = 80;
    };
  };
  services.thermald.enable = true;
  services.fstrim.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Flatpak is the low-tinkering compatibility lane for self-contained GUI
  # apps such as RetroArch. The Sway NixOS module below already
  # provides the required XDG portals. Flathub/apps are bootstrapped per-user
  # by ~/.local/bin/flatpak-bootstrap so rebuilds never wait on downloads.
  services.flatpak.enable = true;
  xdg.portal.enable = true;

  # Native Wayland desktop. XWayland remains available for legacy apps/Wine.
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    xwayland.enable = true;
    extraPackages = [ ];
    extraSessionCommands = ''
      export XDG_SESSION_TYPE=wayland
      export XDG_SESSION_DESKTOP=sway
      export NIXOS_OZONE_WL=1
      export MOZ_ENABLE_WAYLAND=1
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export SDL_VIDEODRIVER=wayland
    '';
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;

  # Sway enables the generic graphical-desktop module, which defaults speechd
  # on. This machine does not use screen-reader speech, so keep that extra
  # socket/service out of the minimal workstation profile.
  services.speechd.enable = false;

  # Practical USB/removable-media support without a GUI automounter. udisks2 is
  # DBus-activated and gives us `udisksctl` for safe user mounts when needed.
  services.udisks2.enable = true;

  # Keep the graphical polkit agent supervised. Fedora Sway normally launches
  # it through autostart, but a user service is more robust: if the agent
  # crashes, systemd brings it back without requiring a logout. The NixOS Sway
  # module imports the live Wayland/DBus environment before starting this target.
  systemd.user.services.rice-polkit-agent = {
    description = "Rice PolicyKit authentication agent";
    wantedBy = [ "sway-session.target" ];
    partOf = [ "sway-session.target" ];
    unitConfig.ConditionUser = "sloth";
    environment = {
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /home/sloth/.local/bin/rice-polkit-agent";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };


  # Tiny Sway IPC subscriber which applies the art-directed window policy:
  # content apps move to dedicated fullscreen workspaces; known utilities occupy
  # fixed free-space zones around the painting focal point. No polling loop and
  # no compositor plugin needed.
  systemd.user.services.rice-window-placement = {
    description = "Rice art-directed window placement";
    wantedBy = [ "sway-session.target" ];
    partOf = [ "sway-session.target" ];
    unitConfig.ConditionUser = "sloth";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /home/sloth/.local/bin/rice-window-placement";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  fonts.packages = with pkgs; [
    ultimate-oldschool-pc-font-pack
  ];
  # Keep the bitmap face as the terminal/UI monospace default only. Do not
  # hijack generic serif/sans fallbacks: webpages and documents need normal
  # proportional fonts and broader Unicode coverage.
  fonts.fontconfig.defaultFonts.monospace = [ "PxPlus IBM VGA 8x16" ];

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    unzip
    libva-utils
    # Fedora Sway also ships an explicit graphical polkit agent. Keep the
    # backend native and use LXQt's tiny agent through a square-style wrapper.
    lxqt.lxqt-policykit
  ];

  users.users.sloth = {
    isNormalUser = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
    # Password remains mutable/persistent; set it once with `passwd sloth`.
  };

  # Appliance-like one-shot tty1 autologin. `autologinOnce` prevents the same
  # account from silently auto-logging into every virtual console and also
  # prevents repeated autologin after the first tty1 session exits.
  services.getty.autologinUser = "sloth";
  services.getty.autologinOnce = true;

  # Fresh NixOS 26.05 install: pin this from now on; do not bump casually.
  system.stateVersion = "26.05";
}

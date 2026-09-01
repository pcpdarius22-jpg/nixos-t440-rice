{ config, lib, pkgs, ... }:
{
  home.username = "sloth";
  home.homeDirectory = "/home/sloth";
  # Fresh NixOS 26.05 install: keep this pinned from now on.
  home.stateVersion = "26.05";

  imports = [ ./apps.nix ./theme.nix ];

  home.sessionPath = [ "$HOME/.local/bin" ];
  fonts.fontconfig = {
    enable = true;
    # Rice chrome explicitly requests the bitmap face. Only the generic
    # monospace fallback is overridden so web/document serif/sans stay natural.
    defaultFonts.monospace = [ "PxPlus IBM VGA 8x16" ];
  };

  home.sessionVariables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";
    TERMINAL = "rice-foot";
    EDITOR = "nvim";
    VISUAL = "nvim";
    BROWSER = "qutebrowser";
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
    font = {
      name = "PxPlus IBM VGA 8x16";
      size = 10;
    };
  };

  programs.bash = {
    enable = true;
    profileExtra = ''
      # Safe graphical auto-start. Any rescue flag keeps tty1 text-only.
      if [ -z "''${WAYLAND_DISPLAY:-}" ] \
         && [ -z "''${DISPLAY:-}" ] \
         && [ "$(tty 2>/dev/null || true)" = "/dev/tty1" ] \
         && [ ! -e "$HOME/.disable-gui" ] \
         && [ ! -e "$HOME/.disable-sway" ] \
         && [ ! -e "$HOME/.disable-x" ]; then
        "$HOME/.local/bin/theme-sync" --startup >/tmp/rice-theme.log 2>&1 || {
          printf '\nTheme preparation failed; staying on tty1. Log: /tmp/rice-theme.log\n'
          return 0 2>/dev/null || true
        }
        sway
        printf '\nSway exited. Staying on tty1. `touch ~/.disable-gui` disables autostart.\n'
      fi
    '';
    bashrcExtra = ''
      PS1='\[\e[38;5;7m\]\u@\h\[\e[0m\] \w $ '
      alias htop='htop -C'
    '';
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
    initLua = ''
      vim.opt.number = false
      vim.opt.relativenumber = false
      vim.opt.cursorline = false
      vim.opt.termguicolors = true
      vim.opt.signcolumn = "no"
      vim.opt.laststatus = 0
      vim.opt.showmode = false
      vim.opt.ruler = false
      vim.opt.showcmd = false
      vim.opt.cmdheight = 1
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.smartindent = true
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.updatetime = 250
      local p = vim.fn.expand("~/.config/rice/generated/nvim-colors.lua")
      if vim.fn.filereadable(p) == 1 then dofile(p) end
    '';
  };

  programs.mpv = {
    enable = true;
    config = {
      hwdec = "auto-safe";
      vo = "gpu-next";
      keep-open = "yes";
      save-position-on-quit = "yes";
      osc = "no";
    };
  };


  # Minimal text clipboard history: one wl-paste watcher, no panel/widget. Open the
  # picker only when needed with Super+V.
  systemd.user.services.rice-cliphist-text = {
    Install.WantedBy = [ "sway-session.target" ];
    Unit = {
      Description = "Rice clipboard history (text)";
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };


  programs.home-manager.enable = true;
}

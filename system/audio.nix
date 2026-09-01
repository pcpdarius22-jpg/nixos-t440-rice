{ ... }:
let
  rice = import ../rice-settings.nix;
  rate = rice.audio.rate;
  studio = rice.audio.studioQuantum;
  safe = rice.audio.safeQuantum;
in
assert builtins.elem studio [ 512 1024 ];
assert builtins.elem safe [ 512 1024 ];
assert safe >= studio;
{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    # T440 music profile: prioritize stability over chasing tiny buffer sizes.
    # REAPER uses the same 512-frame default through reaper-pw. audio-safe can
    # temporarily force 1024 for very heavy projects.
    extraConfig.pipewire."92-t440" = {
      "context.properties" = {
        "default.clock.rate" = rate;
        "default.clock.quantum" = studio;
        "default.clock.min-quantum" = 64;
        "default.clock.max-quantum" = safe;
      };
    };
  };

  security.pam.loginLimits = [
    { domain = "@audio"; type = "-"; item = "rtprio"; value = "95"; }
    { domain = "@audio"; type = "-"; item = "memlock"; value = "unlimited"; }
  ];
}

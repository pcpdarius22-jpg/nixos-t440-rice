{ ... }:
{
  assertions = [
    {
      assertion = false;
      message = ''
        This clean-install package intentionally ships no disk UUIDs.
        Boot the NixOS 26.05 ISO in UEFI mode and run ./install-clean.sh.
        It will run nixos-generate-config against the mounted target and replace
        system/hardware-configuration.nix before evaluating or installing.
      '';
    }
  ];
}

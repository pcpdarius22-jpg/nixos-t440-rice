{
  description = "ThinkPad T440 NixOS 26.05 — Sway monochrome music workstation v12 clean-install RC7";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    nixosConfigurations.thinkpad = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./system/configuration.nix
        ./system/audio.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "v12-backup";
          home-manager.overwriteBackup = true;
          home-manager.users.sloth = import ./user/home.nix;
        }
      ];
    };
  };
}

{
  description = "Helium Browser packaging and NixOS/Home Manager modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{
    self,
    nixpkgs,
    home-manager,
  }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: {
        helium = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        default = self.packages.${system}.helium;
      });

      overlays.default = final: _prev: {
        helium = final.callPackage ./package.nix { };
      };

      nixosModules.default = import ./modules/nixos.nix;
      homeModules.default = import ./modules/home-manager.nix;

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          helium = self.packages.${system}.helium;
        in
        {
          package = helium;

          runtime-smoke = pkgs.runCommand "helium-runtime-smoke" { } ''
            ${helium}/bin/helium --version > $out
          '';

          nixos-module =
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.default
                {
                  programs.helium.enable = true;
                  programs.helium.flags = [ "--ozone-platform=wayland" ];
                  programs.helium.policies = {
                    BrowserSignin = 0;
                    ExtensionInstallBlocklist = [ "*" ];
                  };
                  nixpkgs.hostPlatform = system;
                }
              ];
            }).config.system.build.toplevel;

          home-manager-module =
            (home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                self.homeModules.default
                {
                  home.username = "ci";
                  home.homeDirectory = "/home/ci";
                  home.stateVersion = "25.11";
                  programs.helium.enable = true;
                  programs.helium.flags = [ "--ozone-platform=wayland" ];
                  programs.helium.policies = {
                    BrowserSignin = 0;
                    ExtensionInstallBlocklist = [ "*" ];
                  };
                }
              ];
            }).activationPackage;
        });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

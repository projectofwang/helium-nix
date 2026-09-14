{
  description = "Helium Browser packaging and NixOS/Home Manager modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system: {
        helium = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        default = self.packages.${system}.helium;
      });

      overlays.default = final: _prev: {
        helium = final.callPackage ./package.nix { };
      };

      nixosModules.default = import ./modules/nixos.nix;
      homeModules.default = import ./modules/home-manager.nix;

      checks = forAllSystems (system: {
        package = self.packages.${system}.helium;

        nixos-module =
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              {
                programs.helium.enable = true;
                programs.helium.flags = [ "--ozone-platform=wayland" ];
                nixpkgs.hostPlatform = system;
              }
            ];
          }).config.system.build.toplevel;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };

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

      overlays.default = final: prev: {
        helium = final.callPackage ./package.nix { };
      };

      nixosModules.default = import ./modules/nixos.nix;
      homeModules.default = import ./modules/home-manager.nix;

      checks = forAllSystems (system: {
        helium = self.packages.${system}.helium;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}

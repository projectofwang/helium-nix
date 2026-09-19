{
  description = "Helium Browser packaging and NixOS/Home Manager modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
    }:
    let
      systems = [ "x86_64-linux" ];
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

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          helium = self.packages.${system}.helium;
          customPackage = pkgs.runCommand "custom-helium-package" { } ''
            mkdir -p $out/bin
            cat > $out/bin/helium <<'EOF'
            #!${pkgs.runtimeShell}
            test "$1" = "--test-flag"
            EOF
            chmod +x $out/bin/helium
          '';
        in
        {
          package = helium;

          runtime-smoke = pkgs.runCommand "helium-runtime-smoke" { } ''
            ${helium}/bin/helium --version > $out
          '';

          custom-package-nixos-module =
            let
              systemConfig = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                  self.nixosModules.default
                  {
                    system.stateVersion = "26.05";
                    fileSystems."/" = {
                      device = "tmpfs";
                      fsType = "tmpfs";
                    };
                    boot.loader.grub.devices = [ "/dev/sda" ];
                    programs.helium = {
                      enable = true;
                      package = customPackage;
                      flags = [ "--test-flag" ];
                    };
                    nixpkgs.hostPlatform = system;
                  }
                ];
              };
              packageMatches = nixpkgs.lib.filter (
                candidate: (candidate.name or "") == "helium-with-flags"
              ) systemConfig.config.environment.systemPackages;
              selectedPackage = nixpkgs.lib.findFirst (
                candidate: (candidate.name or "") == "helium-with-flags"
              ) null systemConfig.config.environment.systemPackages;
            in
            assert nixpkgs.lib.assertMsg (builtins.length packageMatches == 1)
              "NixOS Helium module test must install exactly one helium-with-flags package";
            assert nixpkgs.lib.assertMsg (selectedPackage != null)
              "NixOS Helium module test could not locate the helium-with-flags package";
            pkgs.runCommand "helium-custom-package-nixos-module" { } ''
              ${selectedPackage}/bin/helium --test-flag > $out
            '';

          custom-package-home-manager-module =
            let
              activation =
                (home-manager.lib.homeManagerConfiguration {
                  inherit pkgs;
                  modules = [
                    self.homeModules.default
                    {
                      home.username = "ci";
                      home.homeDirectory = "/tmp/helium-home-manager-test";
                      home.stateVersion = "26.05";
                      programs.helium = {
                        enable = true;
                        package = customPackage;
                        flags = [ "--test-flag" ];
                      };
                    }
                  ];
                }).activationPackage;
            in
            pkgs.runCommand "helium-custom-package-home-manager-module" { } ''
              set -euo pipefail

              export HOME=/tmp/helium-home-manager-test
              export USER=ci
              export XDG_STATE_HOME=/tmp/helium-home-manager-state
              mkdir -p "$HOME" "$XDG_STATE_HOME"

              PATH=${pkgs.nix}/bin:$PATH ${activation}/activate --driver-version 1

              helium="$(find "$HOME" -path '*/bin/helium' -print -quit)"
              test -n "$helium"
              "$helium" --test-flag > "$out"
            '';

          nixos-module =
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.default
                {
                  system.stateVersion = "26.05";
                  fileSystems."/" = {
                    device = "tmpfs";
                    fsType = "tmpfs";
                  };
                  boot.loader.grub.devices = [ "/dev/sda" ];
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
                  home.stateVersion = "26.05";
                  programs.helium.enable = true;
                  programs.helium.flags = [ "--ozone-platform=wayland" ];
                  programs.helium.policies = {
                    BrowserSignin = 0;
                    ExtensionInstallBlocklist = [ "*" ];
                  };
                }
              ];
            }).activationPackage;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

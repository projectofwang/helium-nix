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
          customPackage = pkgs.runCommand "custom-helium-package" { } ''
            mkdir -p $out/bin
            cat > $out/bin/helium <<'EOF'
            #!${pkgs.runtimeShell}
            exec ${pkgs.coreutils}/bin/printf '%s\\n' "$@"
            EOF
            chmod +x $out/bin/helium
          '';
        in
        {
          package = helium;

          runtime-smoke = pkgs.runCommand "helium-runtime-smoke" { } ''
            ${helium}/bin/helium --version > $out
          '';

          elf-packaging = pkgs.runCommand "helium-elf-packaging" {
            nativeBuildInputs = [ pkgs.patchelf ];
          } ''
            set -euo pipefail

            for binary in \
              ${helium}/opt/helium/helium \
              ${helium}/opt/helium/helium_crashpad_handler
            do
              test -x "$binary"

              interpreter="$(patchelf --print-interpreter "$binary")"
              case "$interpreter" in
                /nix/store/*) ;;
                *)
                  echo "unexpected ELF interpreter for $binary: $interpreter" >&2
                  exit 1
                  ;;
              esac

              rpath="$(patchelf --print-rpath "$binary")"
              test -n "$rpath"
              case ":$rpath:" in
                *:/usr/*:*|*:/lib/*:*|*:/lib64/*:*)
                  echo "non-Nix ELF RPATH for $binary: $rpath" >&2
                  exit 1
                  ;;
              esac

              while IFS= read -r needed; do
                case "$needed" in
                  /*)
                    echo "absolute ELF dependency for $binary: $needed" >&2
                    exit 1
                    ;;
                esac
              done < <(patchelf --print-needed "$binary")
            done

            touch $out
          '';

          custom-package-nixos-module =
            let
              config =
                (nixpkgs.lib.nixosSystem {
                  inherit system;
                  modules = [
                    self.nixosModules.default
                    {
                      system.stateVersion = "25.11";
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
                }).config.system.build.toplevel;
            in
            pkgs.runCommand "helium-custom-package-nixos-module" { } ''
              touch $out
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
                      home.homeDirectory = "/home/ci";
                      home.stateVersion = "25.11";
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
              touch $out
            '';

          nixos-module =
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.default
                {
                  system.stateVersion = "25.11";
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

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.helium;
  defaultPackage = pkgs.callPackage ../package.nix { };
  package = cfg.package.override { flags = cfg.flags; };
in {
  options.programs.helium = {
    enable = lib.mkEnableOption "Helium Browser";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "inputs.helium.packages.\${pkgs.system}.helium";
      description = "Helium package to install.";
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Chromium/Helium command-line flags.";
    };

    policies = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Managed Helium/Chromium policies written as JSON.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];

    environment.etc."chromium/policies/managed/helium-nixos.json" = lib.mkIf (cfg.policies != { }) {
      text = builtins.toJSON cfg.policies;
    };

    environment.etc."helium/policies/managed/helium-nixos.json" = lib.mkIf (cfg.policies != { }) {
      text = builtins.toJSON cfg.policies;
    };
  };
}

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.helium;

  defaultPackage = pkgs.callPackage ../package.nix { };

  jsonValue = lib.types.oneOf [
    lib.types.bool
    lib.types.int
    lib.types.float
    lib.types.str
    (lib.types.listOf jsonValue)
    (lib.types.attrsOf jsonValue)
  ];

  package =
    if cfg.flags == [ ] then
      cfg.package
    else
      pkgs.symlinkJoin {
        name = "${lib.getName cfg.package}-with-flags";
        paths = [ cfg.package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/helium" \
            ${lib.concatMapStringsSep " \\\n            " (flag: "--add-flags ${lib.escapeShellArg flag}") cfg.flags}
        '';
      };
in {
  options.programs.helium = {
    enable = lib.mkEnableOption "Helium Browser";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "pkgs.callPackage ../package.nix { }";
      description = "Helium package to install.";
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Chromium/Helium command-line flags appended to the launcher.";
    };

    policies = lib.mkOption {
      type = lib.types.attrsOf jsonValue;
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

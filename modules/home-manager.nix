{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.helium;
  defaultPackage = pkgs.callPackage ../package.nix { };
  package = pkgs.symlinkJoin {
    name = "helium-with-flags";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/helium
      makeWrapper ${cfg.package}/bin/helium $out/bin/helium \
        ${lib.concatMapStringsSep " " (flag: "--add-flags ${lib.escapeShellArg flag}") cfg.flags}

      # Re-create the desktop entry so it points at the wrapped binary;
      # skip when the package ships no desktop file (e.g. test stubs).
      if [ -f ${cfg.package}/share/applications/helium.desktop ]; then
        rm -f $out/share/applications/helium.desktop
        substitute ${cfg.package}/share/applications/helium.desktop $out/share/applications/helium.desktop \
          --replace-fail "${cfg.package}/bin/helium" "$out/bin/helium"
      fi
    '';
  };
in
{
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
      description = "Additional Chromium/Helium command-line flags.";
    };

    policies = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Managed Helium/Chromium policies written as JSON.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ package ];

    xdg.configFile."helium/policies/managed/nixos.json" = lib.mkIf (cfg.policies != { }) {
      text = builtins.toJSON cfg.policies;
    };
  };
}

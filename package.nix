{ lib
, appimageTools
, fetchurl
, versionCheckHook
, flags ? [ ]
}:

let
  pname = "helium";
  version = "0.17.0.1";

  sources = {
    x86_64-linux = {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
      hash = "sha256-8qYdEwSh4+8R2Jw4xjYx5XjB0r7s0pYV0w2VvR9Yx4Q=";
    };
    aarch64-linux = {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-arm64.AppImage";
      hash = "sha256-9zdtqM0c+QbwB9f9fV3j+6m5nWjPq1n9o5rK4kK0f3Q=";
    };
  };

  source = sources.${stdenv.hostPlatform.system};
in
appimageTools.wrapType2 {
  inherit pname version;
  src = fetchurl source;

  extraInstallCommands = ''
    install -Dm644 $out/share/applications/*.desktop $out/share/applications/helium.desktop
    substituteInPlace $out/share/applications/helium.desktop \
      --replace-fail 'Exec=helium' 'Exec=helium'

    if [ -f $out/usr/share/icons/hicolor/256x256/apps/helium.png ]; then
      install -Dm644 $out/usr/share/icons/hicolor/256x256/apps/helium.png \
        $out/share/icons/hicolor/256x256/apps/helium.png
    fi
  '';

  extraPkgs = pkgs: with pkgs; [
    libva
    pipewire
    alsa-lib
    cups
    nss
    nspr
    libdrm
    libgbm
    libxkbcommon
    vulkan-loader
    wayland
  ];

  extraBwrapArgs = [
    "--ro-bind-try /run/opengl-driver /run/opengl-driver"
  ];

  passthru = {
    inherit flags;
  };

  meta = {
    homepage = "https://helium.computer";
    description = "Private, fast, and honest web browser based on Chromium";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "helium";
  };
}

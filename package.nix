{ lib
, stdenv
, fetchurl
, dpkg
, patchelf
, makeWrapper
, wrapGAppsHook3
, makeFontsConf
, symlinkJoin
, qt6
, glib
, gsettings-desktop-schemas
, gtk3
, gtk4
, adwaita-icon-theme
, nss
, nspr
, libGL
, libgbm
, libdrm
, libxkbcommon
, libX11
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, libXrender
, libxcb
, libxshmfence
, libXi
, libXcursor
, libXft
, libXScrnSaver
, libXtst
, libSM
, libICE
, alsa-lib
, alsa-plugins
, dbus
, cups
, ffmpeg
, libva
, pipewire
, wayland
, vulkan-loader
, systemd
, xdg-utils
, coreutils
, pango
, cairo
, gdk-pixbuf
, atk
, at-spi2-atk
, at-spi2-core
, freetype
, fontconfig
, libuuid
, expat
, zlib
, libxml2
, libkrb5
, snappy
, udev
, libXt
, binutils
, noto-fonts-cjk-sans
, noto-fonts-cjk-serif
, flags ? [ ]
}:

let
  pname = "helium";
  version = "0.17.0.1";

  sources = {
    x86_64-linux = {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-bin_${version}-1_amd64.deb";
      hash = "sha256-mFj3RECYtEGkh4Zij1NTG3mWHJV8XUnrP0gX1qsc0MI=";
    };
    aarch64-linux = {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-bin_${version}-1_arm64.deb";
      hash = "sha256-Cf87maloOatkkYB7nG8zycoxQYZGzLcxTC6ccnwDnDw=";
    };
  };

  source = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  inherit (lib) optional makeLibraryPath makeSearchPathOutput makeBinPath;

  deps = [
    stdenv.cc.cc nss nspr libGL libgbm libdrm libxkbcommon
    libX11 libXcomposite libXdamage libXext libXfixes libXrandr
    libXrender libxcb libxshmfence libXi libXcursor libXft libXScrnSaver
    libXtst libSM libICE alsa-lib dbus cups ffmpeg libva pipewire wayland
    vulkan-loader systemd pango cairo gdk-pixbuf atk at-spi2-atk
    at-spi2-core freetype fontconfig libuuid expat zlib libxml2 libXt
    libkrb5 snappy udev
  ];

  libPath = makeLibraryPath deps
    + optional (stdenv.hostPlatform.is64bit)
      (":" + makeSearchPathOutput "lib" "lib64" deps)
    + ":$out/opt/helium";

  fontsConf = makeFontsConf {
    fontDirectories = [ noto-fonts-cjk-sans noto-fonts-cjk-serif ];
  };

  alsaPluginDirectory = symlinkJoin {
    name = "helium-alsa-plugins";
    paths = [ "${pipewire}/lib/alsa-lib" "${alsa-plugins}/lib/alsa-lib" ];
  };
in
stdenv.mkDerivation {
  inherit pname version;
  src = fetchurl source;

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [
    patchelf makeWrapper wrapGAppsHook3 qt6.wrapQtAppsHook dpkg binutils
  ];

  dontWrapQtApps = true;

  buildInputs = [
    glib gsettings-desktop-schemas gtk3 gtk4 adwaita-icon-theme
    qt6.qtbase qt6.qtwayland libXt libkrb5 snappy udev systemd
  ];

  unpackPhase = ''
    runHook preUnpack
    ar vx $src
    tar -xvf data.tar.xz
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out $out/bin $out/opt
    cp -r opt/helium $out/opt/helium
    cp -r usr/share $out/share

    for binary in $out/opt/helium/helium $out/opt/helium/helium_crashpad_handler; do
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${libPath}" "$binary"
    done

    for lib in $out/opt/helium/libEGL.so $out/opt/helium/libGLESv2.so; do
      if [ -f "$lib" ]; then
        patchelf --set-rpath "${libPath}" "$lib"
      fi
    done

    substituteInPlace $out/opt/helium/helium-wrapper \
      --replace-fail '$HERE/helium' "$out/opt/helium/helium"

    ln -sf $out/opt/helium/helium-wrapper $out/bin/helium

    substituteInPlace $out/share/applications/helium.desktop \
      --replace-fail 'Exec=helium' "Exec=$out/bin/helium" \
      --replace-fail 'Icon=helium' "Icon=$out/share/icons/hicolor/256x256/apps/helium.png"

    mkdir -p $out/share/icons/hicolor/256x256/apps
    if [ -f $out/opt/helium/product_logo_256.png ]; then
      cp $out/opt/helium/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png
    elif [ -f $out/opt/helium/product_logo.png ]; then
      cp $out/opt/helium/product_logo.png $out/share/icons/hicolor/256x256/apps/helium.png
    fi
    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${libPath}"
      --set ALSA_PLUGIN_DIR "${alsaPluginDirectory}"
      --prefix PATH : "${makeBinPath [ xdg-utils coreutils ]}"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
      --set CHROME_VERSION_EXTRA nix
      --set FONTCONFIG_FILE "${fontsConf}"
      ${lib.concatMapStringsSep "\n      " (f: "--add-flags \"${f}\"") flags}
    )
  '';

  meta = {
    homepage = "https://helium.computer";
    description = "Private, fast, and honest web browser based on Chromium";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "helium";
  };
}

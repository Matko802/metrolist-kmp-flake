{
  appimageTools,
  fetchurl,
  glib-networking,
  lib,
  makeWrapper,
  symlinkJoin,
  systemFont ? "sans-serif",
  waylandScale ? null,
}:

let
  pname = "metrolist-kmp-flake";
  sources = import ./sources.nix;
  inherit (sources) version;

  src = fetchurl {
    inherit (sources) url hash;
    name = "metrolist-desktop-linux-x64-${version}.AppImage";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };

  fontconfig = builtins.toFile "metrolist-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      ${lib.concatMapStrings (family: ''
        <match target="pattern">
          <test qual="any" name="family"><string>${family}</string></test>
          <edit name="family" mode="assign" binding="strong"><string>${lib.escapeXML systemFont}</string></edit>
        </match>
      '') [ "Noto Sans" "DejaVu Sans" "Arial" ]}
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
    </fontconfig>
  '';

  app = appimageTools.wrapAppImage {
    inherit pname version;

    src = appimageContents;

    extraPkgs =
      pkgs: with pkgs; [
        webkitgtk_4_1
      ];

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/Metrolist.desktop $out/share/applications/metrolist-kmp-flake.desktop
      chmod u+w $out/share/applications/metrolist-kmp-flake.desktop
      substituteInPlace $out/share/applications/metrolist-kmp-flake.desktop \
        --replace-fail 'Exec=bin/Metrolist' 'Exec=metrolist-kmp-flake' \
        --replace-fail 'Icon=Metrolist' 'Icon=metrolist-kmp-flake'
      install -Dm444 ${appimageContents}/Metrolist.png $out/share/icons/hicolor/512x512/apps/metrolist-kmp-flake.png
      install -Dm444 ${appimageContents}/Metrolist.png $out/share/pixmaps/metrolist-kmp-flake.png
    '';

    meta = with lib; {
      description = "Metrolist KMP desktop music player packaged from the upstream AppImage";
      longDescription = ''
        Metrolist is a YouTube Music client. This package wraps the upstream
        Compose Multiplatform (KMP) desktop AppImage and adds WebKitGTK 4.1 so
        embedded web views (login dialogs, Last.fm browser) work on NixOS.
      '';
      homepage = "https://github.com/MetrolistGroup/Metrolist";
      license = licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      mainProgram = "metrolist-kmp-flake";
    };
  };
in
symlinkJoin {
  name = "${pname}-${version}";

  paths = [ app ];

  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    wrapProgram $out/bin/metrolist-kmp-flake \
      --prefix GIO_EXTRA_MODULES : ${glib-networking}/lib/gio/modules \
      --set FONTCONFIG_FILE ${fontconfig} ${lib.optionalString (waylandScale != null) "--set METROLIST_FORCE_SCALE ${lib.escapeShellArg waylandScale}"}
  '';

  meta = app.meta;
}

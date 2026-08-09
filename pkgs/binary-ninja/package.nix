# Binary Ninja, azzie's LICENSED personal build. nixpkgs only packages
# binaryninja-free (whose src is a public github release); the paid build is a
# per-account download behind a login, so there is NO url to fetch and this uses
# requireFile. the zip is never committed or redistributed, only its hash, which
# keeps the public mirror clean.
#
# updating: download the new zip, then
#   nix-store --add-fixed sha256 ~/Downloads/binaryninja_linux_dev_personal.zip
#   nix hash file --sri --type sha256 ~/Downloads/binaryninja_linux_dev_personal.zip
# and bump version + hash here. BN's IN-APP updater cannot work from a read-only
# store path, that is the deliberate trade for a declarative install (it fails
# harmlessly; do not "fix" it by making the tree writable).
#
# WHY autoPatchelf and not the old steam-run FHS wrapper: BN bundles its whole
# runtime (Qt 6.11, python 3.13, lldb 22), so only the leaf system libs are
# missing. patching them once at build time makes the launch path a plain exec,
# no FHS namespace, and drops the programs.steam dependency for an RE tool.
#
# cross-file deps: home/modules/desktop/binary-ninja.nix (theme + plugins + the
# launcher that puts this on PATH), modules/nixos/re.nix (binja-mcp bridge).
{
  lib,
  stdenv,
  requireFile,
  unzip,
  autoPatchelfHook,
  curl,
  dbus,
  fontconfig,
  freetype,
  glib,
  libdrm,
  libGL,
  libGLU,
  libedit,
  libxkbcommon,
  libxml2,
  ncurses,
  openssl,
  wayland,
  xcb-util-cursor,
  sqlite,
  xorg,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-wm,
  zlib,
  zstd,
}:
stdenv.mkDerivation {
  pname = "binary-ninja";
  version = "5.4.10350-dev";

  # the filename must match the download exactly: requireFile resolves the store
  # path by (name, hash), so a renamed zip silently misses.
  src = requireFile {
    name = "binaryninja_linux_dev_personal.zip";
    hash = "sha256-eXuJWMl3W47m7GmkCZGlCsuFzzxRJHwEIrsQCPS5Mao=";
    url = "https://binary.ninja/recover/ (log in, Download > Linux)";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  # leaf system libs the bundled Qt/lldb/python link against. the xcb-util family
  # + xcb-cursor are the qt6 xcb platform plugin's hard deps (qt6 refuses to start
  # without libxcb-cursor); ncurses/libedit/zstd are lldb's, openssl is the
  # bundled python's.
  buildInputs = [
    curl
    dbus
    fontconfig
    freetype
    glib
    libdrm
    libGLU
    libedit
    libxkbcommon
    libxml2
    ncurses
    openssl
    sqlite
    stdenv.cc.cc.lib
    wayland
    xcb-util-cursor
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXcursor
    xorg.libXext
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libxcb
    xorg.xcbutil
    zlib
    zstd
  ];

  # qt + BN resolve GL through dlopen, so autoPatchelf never sees the need
  runtimeDependencies = [ (lib.getLib libGL) ];

  # PySide6 ships two standalone dev helpers (qsb, svgtoqml) that link Qt Quick,
  # which BN does NOT bundle. neither is on any BN code path. satisfying them
  # would mean pulling nixpkgs qt6 in beside the bundled 6.11.1 and risking an
  # ABI mismatch in the libs that actually matter, so leave them broken instead.
  autoPatchelfIgnoreMissingDeps = [
    "libQt6Quick.so.6"
    "libQt6QuickVectorImageGenerator.so.6"
    "libQt6ShaderTools.so.6"
  ];

  sourceRoot = "binaryninja";

  # NO desktop item here on purpose: home/modules/desktop/binary-ninja.nix owns
  # the .desktop, because the thing that must be launched is its PYTHONPATH
  # wrapper, not this bin/binaryninja directly. shipping both would also collide
  # on bin/binaryninja in the home-manager profile buildEnv.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/binaryninja $out/bin
    cp -r . $out/lib/binaryninja/
    ln -s $out/lib/binaryninja/binaryninja $out/bin/binaryninja

    install -Dm644 api-docs/cpp/logo.png \
      $out/share/icons/hicolor/256x256/apps/binaryninja.png

    runHook postInstall
  '';

  meta = {
    description = "Interactive decompiler, disassembler, debugger (licensed personal build)";
    homepage = "https://binary.ninja/";
    license = {
      fullName = "Binary Ninja Personal License";
      url = "https://binary.ninja/purchase/";
      free = false;
    };
    sourceProvenance = with lib.sourceProvenance; [ binaryNativeCode ];
    mainProgram = "binaryninja";
    platforms = [ "x86_64-linux" ];
  };
}

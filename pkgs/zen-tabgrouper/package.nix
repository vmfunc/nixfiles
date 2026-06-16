# Tabgrouper: the Zen extension that has Claude sort tabs into groups live, plus
# the native-messaging host that holds the API key and makes the Haiku call.
#
# This builds three things and exposes them as one derivation (the unsigned XPI)
# with the rest in passthru, so the home-manager module can pick what it needs:
#   - .xpi      : the unsigned packed extension (for `web-ext sign` / temp load)
#   - extDir    : the unpacked source tree (for `web-ext run` dev loading)
#   - host      : the python native-messaging host wrapper (+x, on PATH)
#   - geckoId / hostName : the load-bearing identifiers, single-sourced here
#
# Cross-platform on purpose (pure zip + stdlib python): the module callPackages
# it directly so it evaluates on NixOS too, not only through the darwin overlay.
{
  lib,
  stdenv,
  python3,
  zip,
  writeShellApplication,
}:
let
  version = "0.1.0";
  geckoId = "tabgrouper@vmfunc.re";
  hostName = "re.vmfunc.tabgrouper";

  # The host wrapper just execs python on the script and forwards args (the
  # module passes --key-file). stdlib only, so plain python3 with no env.
  host = writeShellApplication {
    name = "tabgrouper-host";
    runtimeInputs = [ python3 ];
    text = ''
      exec ${python3}/bin/python3 ${./host/tabgrouper_host.py} "$@"
    '';
  };

  # The source tree, materialised in the store for web-ext --source-dir.
  extDir = stdenv.mkDerivation {
    pname = "tabgrouper-ext";
    inherit version;
    src = ./ext;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r ./. "$out/"
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "tabgrouper";
  inherit version;
  src = ./ext;
  nativeBuildInputs = [ zip ];
  dontConfigure = true;

  # An XPI is just a zip with manifest.json at the root. Build it deterministically
  # (sorted entries, no extra attributes, fixed mtime) so the store path is stable.
  buildPhase = ''
    runHook preBuild
    find . -exec touch -d @''${SOURCE_DATE_EPOCH:-315532800} {} +
    zip -r -X -9 -D tabgrouper.xpi . -x '*.DS_Store' | tail -1
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 tabgrouper.xpi "$out/share/tabgrouper/${geckoId}.xpi"
    runHook postInstall
  '';

  passthru = {
    inherit
      host
      extDir
      geckoId
      hostName
      version
      ;
    # the on-disk path of the packed unsigned xpi, for `web-ext sign`
    xpiPath = "share/tabgrouper/${geckoId}.xpi";
  };

  meta = {
    description = "Claude auto-sorts Zen tabs into named groups; collapse/close to free RAM, restore later";
    platforms = lib.platforms.all;
  };
}

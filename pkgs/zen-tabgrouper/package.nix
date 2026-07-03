# tabgrouper: the zen extension that has Claude sort tabs into groups live, plus the
# native-messaging host that holds the api key and makes the Haiku call.
#
# the derivation output IS the unsigned packed xpi (for `web-ext sign` / temp load);
# passthru carries the host wrapper (+x, on PATH) and the load-bearing geckoId/hostName,
# single-sourced here. the dev loop (`zen-tabgrouper-dev`) web-ext runs the live repo
# checkout, so no store copy of the source tree is needed. cross-platform on purpose
# (pure zip + stdlib python): the module callPackages it directly so it evaluates on
# nixos too, not only through the darwin overlay.
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

  # the host wrapper just execs python on the script and forwards args (the
  # module passes --key-file). stdlib only, so plain python3 with no env.
  host = writeShellApplication {
    name = "tabgrouper-host";
    runtimeInputs = [ python3 ];
    text = ''
      exec ${python3}/bin/python3 ${./host/tabgrouper_host.py} "$@"
    '';
  };
in
stdenv.mkDerivation {
  pname = "tabgrouper";
  inherit version;
  src = ./ext;
  nativeBuildInputs = [ zip ];
  dontConfigure = true;

  # an xpi is just a zip with manifest.json at the root. -X drops uid/gid + extra
  # attributes and the fixed mtime (SOURCE_DATE_EPOCH) keeps the store path stable.
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
      geckoId
      hostName
      version
      ;
  };

  meta = {
    description = "Claude auto-sorts Zen tabs into named groups; collapse/close to free RAM, restore later";
    platforms = lib.platforms.all;
  };
}

# iphone notifications on linux over bluetooth LE, via ANCS (the same protocol
# apple watches speak). three daemons: observer + advertising (root, system dbus)
# and desktop-integration (user session -> freedesktop notifications). upstream
# ships no release tags, so this pins master; upstream's autorun/ units hardcode
# /usr/local/bin, so modules/nixos/iphone.nix declares its own systemd units and
# only the dbus policies are reused from the source tree here.
{
  lib,
  python3Packages,
  fetchFromGitHub,
  gobject-introspection,
  wrapGAppsNoGuiHook,
}:
python3Packages.buildPythonApplication {
  pname = "ancs4linux";
  version = "1.0.0-unstable-2026-05-24";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "pzmarzly";
    repo = "ancs4linux";
    rev = "985b8d07681e41785fc589149fe520f8ba5d325c";
    hash = "sha256-Z998P9P7Yu055UwrRjA1uMTG/uJsH6MvlhzDURpG4dM=";
  };

  build-system = [ python3Packages.hatchling ];
  dependencies = with python3Packages; [
    dasbus
    pygobject3
    typer
  ];

  # pygobject needs GI_TYPELIB_PATH at runtime; the no-gui hook collects it
  # without dragging in gtk. dontWrapGApps + makeWrapperArgs is the standard
  # python dance (the python wrapper and the gapps wrapper would double-wrap).
  nativeBuildInputs = [
    gobject-introspection
    wrapGAppsNoGuiHook
  ];
  dontWrapGApps = true;
  makeWrapperArgs = [ "\${gappsWrapperArgs[@]}" ];

  # dbus refuses bus-name ownership without these policies; services.dbus.packages
  # picks them up from share/dbus-1.
  postInstall = ''
    install -Dm644 autorun/ancs4linux-observer.xml \
      $out/share/dbus-1/system.d/ancs4linux-observer.conf
    install -Dm644 autorun/ancs4linux-advertising.xml \
      $out/share/dbus-1/system.d/ancs4linux-advertising.conf
  '';

  meta = {
    description = "iOS/iPadOS notification client over bluetooth LE (ANCS)";
    homepage = "https://github.com/pzmarzly/ancs4linux";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "ancs4linux-ctl";
  };
}

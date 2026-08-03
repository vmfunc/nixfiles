# xdg-desktop-portal RemoteDesktop backend for compositors that expose virtual
# input protocols but ship no RemoteDesktop impl (niri, sway, ...). kdeconnect's
# mousepad plugin drives remote input through the portal (26.04+ prefers
# ConnectToEIS; the bridge accepts both paths) and replays it via
# zwlr_virtual_pointer_v1 + zwp_virtual_keyboard_v1, both live on niri 25.08.
# upstream ships no tags, so this pins master. consumed by
# modules/nixos/kdeconnect.nix (xdg.portal.extraPortals + niri portal routing).
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt6,
  wayland,
  wayland-scanner,
  libxkbcommon,
  libei,
  kdePackages,
}:

stdenv.mkDerivation {
  pname = "wayland-kdeconnect-fix";
  version = "0.1.0-unstable-2026-05-05";

  src = fetchFromGitHub {
    owner = "iamnarayana";
    repo = "wayland-kdeconnect-fix";
    rev = "ea55f66c8238235983d60d381bf2abe1fed50043";
    hash = "sha256-OW18+pO92XvlTLrHo+S9/EVUophr5Dl1GdGJcmVAq/o=";
  };

  # kdeconnectd calls the portal from a second, NAMELESS dbus connection, so
  # upstream's "sender owns org.kde.kdeconnect" gate always refuses it (verified
  # live: names owned by :1.N, CreateSession arrives from :1.N+1, same pid).
  # match by pid instead of unique name; candidate for upstreaming.
  patches = [ ./dbus-name-gate-same-pid.patch ];

  # threat model: this daemon injects input into the session, so it only serves
  # callers it can attribute to kdeconnect. when the portal app-id resolves
  # empty (host processes outside an app-*.scope cgroup, i.e. the home-manager
  # kdeconnectd unit) it falls back to an exe-path allowlist that upstream pins
  # to FHS locations, none of which exist here. repoint the entries at the store
  # path of the kdeconnectd we actually ship, keeping the policy pinned rather
  # than loosened to a basename match. the check reads /proc/<pid>/exe, and
  # bin/kdeconnectd is a nixpkgs qt wrapper that execs .kdeconnectd-wrapped, so
  # the WRAPPED path is the one that must match (verified live on guppy); the
  # plain bin path stays too in case the wrapper ever goes away.
  postPatch = ''
    substituteInPlace src/security_policy.hpp \
      --replace-fail '"/usr/bin/kdeconnectd"' '"${kdePackages.kdeconnect-kde}/bin/kdeconnectd"' \
      --replace-fail '"/usr/lib/kdeconnectd"' '"${kdePackages.kdeconnect-kde}/bin/.kdeconnectd-wrapped"' \
      --replace-fail '"/usr/libexec/kdeconnectd"' '"${kdePackages.kdeconnect-kde}/libexec/kdeconnectd"'
    # the policy test pins the same FHS path; retarget it so the allow-case
    # still exercises the patched list (the deny-cases stay untouched).
    substituteInPlace tests/security_policy_test.cpp \
      --replace-fail '"/usr/bin/kdeconnectd"' '"${kdePackages.kdeconnect-kde}/bin/kdeconnectd"'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    wayland-scanner
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    wayland
    libxkbcommon
    libei
  ];

  # upstream's ctest suite: key/keysym resolution, the caller policy above, a
  # readelf pass over the hardening flags, and portal metadata consistency.
  doCheck = true;

  meta = {
    description = "RemoteDesktop portal backend bridging KDE Connect remote input to wlr virtual-input protocols";
    homepage = "https://github.com/iamnarayana/wayland-kdeconnect-fix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hypr-kdeconnect-portal";
  };
}

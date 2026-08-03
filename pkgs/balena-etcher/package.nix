# balena etcher, repacked from the upstream .deb. nixpkgs dropped `etcher` when
# its electron 19 base went EOL, and upstream v2.x ships no AppImage anymore
# (deb/rpm/zip only), so this is the slack/discord-style blob repack:
# autoPatchelfHook over the bundled electron + the elevated writer helper
# (resources/etcher-util, spawned via pkexec/sudo when flashing). consumed from
# modules/nixos/apps.nix; x86_64-linux only because upstream builds no linux-arm64.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-core,
  cups,
  expat,
  gtk3,
  libdrm,
  libgbm,
  libxkbcommon,
  libGL,
  nspr,
  nss,
  systemd,
  xorg,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "balena-etcher";
  version = "2.1.6";

  src = fetchurl {
    url = "https://github.com/balena-io/etcher/releases/download/v${finalAttrs.version}/balena-etcher_${finalAttrs.version}_amd64.deb";
    hash = "sha256-K967Rsn3UKmr8RwYj/aaQFtKT+0RQzPWNMOz/lmmQFc=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  # sonames the bundled chromium + native node modules link against. gtk3
  # propagates the glib/cairo/pango/gdk-pixbuf family, so only the rest is
  # spelled out. libudev (systemd) is drivelist's device enumeration.
  buildInputs = [
    alsa-lib
    at-spi2-core
    cups
    expat
    gtk3
    libdrm
    libgbm
    libxkbcommon
    nspr
    nss
    (lib.getLib systemd)
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
  ];

  # chromium dlopens gl at runtime (no DT_NEEDED), so autoPatchelf can't see it;
  # append to every patched elf's runpath instead
  runtimeDependencies = [ (lib.getLib libGL) ];

  # not `dpkg -x`: it restores chrome-sandbox's suid bit, which the build
  # sandbox refuses (and the store would strip anyway; electron uses the userns
  # sandbox here, not the suid helper)
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r usr/lib $out/lib
    cp -r usr/share $out/share
    runHook postInstall
  '';

  # the ozone guard is the stock nixpkgs electron dance: native wayland when the
  # session provides it (guppy/tuna set NIXOS_OZONE_WL), xwayland fallback
  # otherwise. shell makeWrapper on purpose, the ''${} expansion happens at
  # launch time.
  postFixup = ''
    makeWrapper $out/lib/balena-etcher/balena-etcher $out/bin/balena-etcher \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  '';

  meta = {
    description = "flash os images to sd cards and usb drives, safely and easily";
    homepage = "https://etcher.balena.io";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceProvenance; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "balena-etcher";
  };
})

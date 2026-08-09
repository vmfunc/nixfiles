# cake wallet: open-source non-custodial XMR/BTC/ETH/LTC wallet. NOT in nixpkgs
# and NOT shipped as an appimage, so this packages the official flutter linux
# bundle (tar.xz) straight off github with autoPatchelf. linux/tuna-only.
#
# version dance: the linux desktop build lags the mobile app by a patch, so the
# v6.3.0 bundle is attached to the v6.3.2 release tag. keep releaseTag + version
# split so the url templates cleanly.
# TODO(deploy): to bump, find the newest "*_Linux.tar.xz" on the releases page,
#   set releaseTag + version below, then refresh the hash:
#   `nix hash convert --to sri sha256:$(nix-prefetch-url <url>)`. drop this whole
#   module for nixpkgs `cake-wallet` if it ever lands upstream.
#
# cross-file deps: imported from home/tuna.nix (tuna-scoped; the app is the only
# consumer). autoPatchelf resolves the bundled lib/*.so flutter plugins itself;
# buildInputs cover only the external gtk3 runtime + the keyring/crypto libs the
# vendored monero/warp objects reach for.
{ pkgs, lib, ... }:
let
  releaseTag = "v6.3.2";
  version = "6.3.0";

  cake-wallet = pkgs.stdenv.mkDerivation {
    pname = "cake-wallet";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/cake-tech/cake_wallet/releases/download/${releaseTag}/Cake_Wallet_v${version}_Linux.tar.xz";
      hash = "sha256-+UK9cpa/c64WnN9ATCPRISdJK598qgjXqExh0jicd20=";
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      wrapGAppsHook3
      makeWrapper
      copyDesktopItems
    ];

    buildInputs = with pkgs; [
      gtk3
      glib
      pango
      cairo
      harfbuzz
      atk
      gdk-pixbuf
      libepoxy
      fontconfig
      libsecret
      stdenv.cc.cc.lib
    ];

    dontConfigure = true;
    dontBuild = true;

    # url_launcher shells out to xdg-open at runtime; fold it into the gtk wrapper
    # rather than leaking it onto the user PATH. gappsWrapperArgs is only populated
    # in preFixup, so extend it there and let wrapGAppsHook3 do the actual wrap.
    preFixup = ''
      gappsWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ pkgs.xdg-utils ]})
    '';

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "cake-wallet";
        exec = "cake-wallet";
        icon = "cake-wallet";
        desktopName = "Cake Wallet";
        comment = "Open-source non-custodial XMR/BTC/ETH wallet";
        categories = [
          "Office"
          "Finance"
        ];
      })
    ];

    installPhase = ''
      runHook preInstall

      install -dm755 $out/opt/cake-wallet
      cp -r . $out/opt/cake-wallet/

      install -Dm644 \
        $out/opt/cake-wallet/data/flutter_assets/assets/images/cakewallet_icon_1024.png \
        $out/share/pixmaps/cake-wallet.png

      makeWrapper $out/opt/cake-wallet/cake_wallet $out/bin/cake-wallet

      runHook postInstall
    '';

    meta = {
      description = "Open-source non-custodial XMR/BTC/ETH wallet (linux desktop bundle)";
      homepage = "https://cakewallet.com";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      mainProgram = "cake-wallet";
    };
  };
in
{
  home.packages = [ cake-wallet ];
}

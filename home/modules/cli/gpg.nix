{ pkgs, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  pinentryPkg = if isDarwin then pkgs.pinentry_mac else pkgs.pinentry-curses;
  pinentryProgram = if isDarwin then "pinentry-mac" else "pinentry-curses";

  cacheTtl = 86400;

  # auth subkey keygrip (card slot 3); gpg --with-keygrip -K, line under [A]
  sshAuthKeygrip = "REPLACE_ME_AUTH_SUBKEY_KEYGRIP";
in
{
  home.packages = [
    pkgs.gnupg
    pinentryPkg
  ];

  services.gpg-agent = {
    enable = true;

    pinentry = {
      package = pinentryPkg;
      program = pinentryProgram;
    };

    defaultCacheTtl = cacheTtl;
    maxCacheTtl = cacheTtl;

    # pinentry-mac grabbing input is unwanted
    grabKeyboardAndMouse = false;

    enableSshSupport = true;
    sshKeys = [ sshAuthKeygrip ];

    extraConfig = ''
      allow-loopback-pinentry
    '';
  };

  programs.gpg.scdaemonSettings = {
    # reader name from pcsc_scan; enable both together once confirmed
    # disable-ccid = true;
    # reader-port = "Ledger Nano S Plus OpenPGP";
  };
}

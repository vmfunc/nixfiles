{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  pinentryPkg = if isDarwin then pkgs.pinentry_mac else pkgs.pinentry-curses;
  pinentryProgram = if isDarwin then "pinentry-mac" else "pinentry-curses";

  cacheTtl = 86400;

  # auth subkey keygrip from the Ledger (card slot 3). plug the Ledger in, run
  # `gpg --card-status` then `gpg --list-secret-keys --with-keygrip`, and copy the
  # keygrip printed under the [A] subkey here. left empty until then: the guard
  # below keeps gpg-agent ssh support OFF so no placeholder reaches sshcontrol.
  sshAuthKeygrip = "";
  haveSshKey = sshAuthKeygrip != "";
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

    # only flips on once a real Ledger auth keygrip is set above; until then ssh
    # stays out of gpg-agent and no bogus keygrip is written into sshcontrol.
    enableSshSupport = haveSshKey;
    sshKeys = lib.optionals haveSshKey [ sshAuthKeygrip ];

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

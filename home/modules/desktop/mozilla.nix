# the mozilla apps besides firefox. plain packages: thunderbird drives its own
# profile/account state imperatively (programs.thunderbird would want the whole
# account tree declared, not worth it for a mail client azzie logs into once).
# scoped via desktop-linux, so every linux desktop (tuna/minnow/guppy) gets them.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    thunderbird # mail / calendar
    seamonkey # the legacy all-in-one mozilla suite (browser + mail + composer)
    mozillavpn # mozilla vpn client
  ];
}

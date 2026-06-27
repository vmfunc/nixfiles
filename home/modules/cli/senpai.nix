# senpai — modern TUI IRC client (~taiite, sr.ht). built for bouncers, so it pairs
# cleanly with the sr.ht chat bouncer (soju): the bouncer remembers joined channels,
# senpai just attaches. config is scfg, rendered by the home-manager freeform module.
#
# cross-file deps:
#   - the terminal palette IS senpai's theme. wezterm/ghostty paint the 16 ANSI from
#     theme.ansi16 (per variant), so senpai's UI is already wired-colored; here we only
#     pin the accent slots. colors are ANSI INDICES on purpose: index 5 = the accent
#     (plum-rose in blood), index 4 = the structure/purple-blue slot. they follow the
#     terminal palette, and they sidestep scfg's `#` (which would start a comment if we
#     wrote a raw hex value).
#   - secrets/irc.yaml (sops): the sr.ht bouncer SASL token, decrypted at activation and
#     read at runtime via password-cmd. declared below so it only lands on the macs that
#     import this module (home/profiles/desktop-darwin.nix).
#
# auth: SASL username = nickname (vmfunc, the sr.ht account); password = the bouncer
# token from sops. address is the sr.ht bouncer (TLS default, port 6697).
{
  config,
  ...
}:
let
  ircPass = config.sops.secrets."irc-password".path;
in
{
  sops.secrets."irc-password" = {
    sopsFile = ../../../secrets/irc.yaml;
    key = "password";
  };

  programs.senpai = {
    enable = true;
    config = {
      address = "chat.sr.ht:6697";
      nickname = "vmfunc";
      # first line of stdout is the SASL password; keeps the token off the store.
      password-cmd = [
        "cat"
        ircPass
      ];

      pane-widths = {
        nicknames = 12;
        channels = 18;
        members = 16;
      };

      # accent slots only; everything else inherits the terminal's wired ANSI palette.
      colors = {
        prompt = 5; # accent (plum-rose in blood)
        unread = 4; # purple-blue structure slot
      };
    };
  };
}

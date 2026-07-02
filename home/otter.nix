{ ... }:
{
  imports = [
    ./core.nix
    ./profiles/base.nix
    ./profiles/desktop-darwin.nix
    ./profiles/security.nix
  ];

  # otter's Zen profile, so the native-groups pref (and a signed XPI later) land
  # in the right place. Host-specific because the profile id differs per machine.
  rice.zenTabgrouper.profilePath = "Library/Application Support/zen/Profiles/c6bgtaur.Default (release)";

  # the laptop roams, so auto-mount the home NAS (smb://192.168.1.89 quaver + shared)
  # only when actually on the home network; tears down when away. password via sops.
  rice.homeMounts.enable = true;

  # lumen off on the laptop: its continuous screen-capture + GPU render loop is a
  # battery drain and pointless with the lid shut. stays on for coral (the desk box).
  rice.lumen.enable = false;

  # cap Zen to 60fps: the dev-panel-free stable build still repaints the ProMotion
  # display at 120Hz idle, doubling GPU/fan for nothing. coral (AC) stays uncapped.
  rice.zen.frameRateCap = 60;
}

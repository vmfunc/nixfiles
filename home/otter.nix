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
}

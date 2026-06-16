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
}

# decrypts secrets at activation with the age key (darwin: ~/Library/…, linux: ~/.config/…)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ageKeyFile =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/sops/age/keys.txt"
    else
      "${config.xdg.configHome}/sops/age/keys.txt";
in
{
  sops = {
    age.keyFile = ageKeyFile;
    defaultSopsFile = ../../../secrets/restic.yaml;
    secrets."restic-password" = { };

    # forgejo token, deployed as the nix netrc so private flake inputs fetch
    secrets."nix-netrc" = {
      sopsFile = ../../../secrets/nix.yaml;
      key = "netrc";
      path = "${config.home.homeDirectory}/.config/nix/netrc";
      mode = "0600";
    };
  };

  # fail loud if the age key is missing instead of every secret silently breaking
  home.activation.checkSopsAgeKey = lib.hm.dag.entryBefore [ "sops-nix" ] ''
    if [ ! -f "${ageKeyFile}" ]; then
      echo "sops: age key missing at ${ageKeyFile}; secrets won't decrypt" >&2
      exit 1
    fi
  '';
}

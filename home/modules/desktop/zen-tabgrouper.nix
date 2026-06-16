# Zen tabgrouper: Claude sorts open tabs into named groups live, and you can
# collapse (discard, free RAM) or close (save + free RAM, reopen later) a group.
#
# Four declarative pieces, all wired here:
#   1. the Anthropic key via sops-nix, to a fixed 0600 path the host reads;
#   2. the python native-messaging host wrapper (holds the key, calls Haiku);
#   3. the native-messaging manifest in the MOZILLA vendor dir (authoritative on
#      Zen, confirmed from the live XUL binary + Gecko nsXREDirProvider), pointed
#      at a launcher that passes the key path;
#   4. (optional) a signed XPI sideloaded into the Zen profile.
#
# Zen ENFORCES extension signing (compiled-in MOZ_REQUIRE_SIGNING; the about:config
# toggle is inert), so the unsigned build only loads via web-ext / temporary load.
# Permanent install needs a `web-ext sign --channel unlisted` XPI -> set signedXpi.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.zenTabgrouper;

  # callPackage directly (not pkgs.zen-tabgrouper) so this evaluates on NixOS too;
  # the custom-pkgs overlay is darwin-gated.
  pkg = pkgs.callPackage ../../../pkgs/zen-tabgrouper/package.nix { };
  inherit (pkg) geckoId hostName;

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # sops decrypts the key here at activation; the host reads it at runtime.
  keyFile = "${config.xdg.configHome}/tabgrouper/anthropic-key";

  # What the native-messaging manifest's "path" points at: a tiny +x store script
  # that execs the host with the sops key path. (The manifest can't set env, so
  # the key path is baked into this launcher.)
  launcher = pkgs.writeShellScript "tabgrouper-host-launch" ''
    exec ${pkg.host}/bin/tabgrouper-host --key-file ${lib.escapeShellArg keyFile}
  '';

  manifest = builtins.toJSON {
    name = hostName;
    description = "Tabgrouper classifier host (holds the Anthropic key, calls Claude Haiku)";
    path = "${launcher}";
    type = "stdio";
    allowed_extensions = [ geckoId ];
  };

  # macOS uses PascalCase "NativeMessagingHosts"; Linux uses dashed lowercase.
  mozManifestPath =
    if isDarwin then
      "Library/Application Support/Mozilla/NativeMessagingHosts/${hostName}.json"
    else
      ".mozilla/native-messaging-hosts/${hostName}.json";

  # Zero-cost hedge (darwin): also drop it in a zen-named dir against a future
  # LibreWolf-style dual-dir patch. Dead today, harmless.
  zenManifestPath = "Library/Application Support/zen/NativeMessagingHosts/${hostName}.json";

  # Dev loop: web-ext run against the live Zen binary, pointed at the repo source
  # so edits hot-reload. Needs no signing.
  devTool = pkgs.writeShellApplication {
    name = "zen-tabgrouper-dev";
    runtimeInputs = [ pkgs.web-ext ];
    text = ''
      src="''${1:-$HOME/mac-rice/pkgs/zen-tabgrouper/ext}"
      zen="${if isDarwin then "/Applications/Zen.app/Contents/MacOS/zen" else "zen"}"
      echo "loading $src into $zen (temporary, unsigned)..."
      exec web-ext run --source-dir "$src" --firefox "$zen" --keep-profile-changes
    '';
  };
in
{
  options.rice.zenTabgrouper = {
    enable = lib.mkEnableOption "the Zen tabgrouper extension (Claude-sorted tab groups)";

    signedXpi = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a Mozilla-signed (`web-ext sign --channel unlisted`) XPI to install
        permanently into the Zen profile. Zen enforces signing, so an unsigned XPI
        will NOT load. Leave null and develop via `zen-tabgrouper-dev` (web-ext
        temporary load) until AMO signing creds are available.
      '';
    };

    profilePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Library/Application Support/zen/Profiles/c6bgtaur.Default (release)";
      description = ''
        home-relative path to the Zen profile to sideload the signed XPI into
        (its extensions/ dir). Null = touch no profile. Only used with signedXpi.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."anthropic-api-key" = {
      sopsFile = ../../../secrets/anthropic.yaml;
      path = keyFile;
      mode = "0600";
    };

    home.packages = [
      pkg.host
      devTool
      pkgs.web-ext
    ];

    home.file = lib.mkMerge [
      { ${mozManifestPath}.text = manifest; }
      (lib.mkIf isDarwin { ${zenManifestPath}.text = manifest; })
      (lib.mkIf (cfg.signedXpi != null && cfg.profilePath != null) {
        "${cfg.profilePath}/extensions/${geckoId}.xpi".source = cfg.signedXpi;
      })
    ];
  };
}

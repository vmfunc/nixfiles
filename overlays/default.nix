{ ... }:
{
  # gate on prev.stdenv, reading final.stdenv to pick overlay keys recurses
  additions =
    final: prev: prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin (import ../pkgs final);

  modifications = _final: prev: {
    # stale go vendorHash upstream
    sif = prev.sif.overrideAttrs (_: {
      vendorHash = "sha256-tBRRhYl3qevnbK71Or4ksQzlwE90yUG7FvxEV6DmFFw=";
    });

    # john "rolling" ships a stale source hash
    john = prev.john.overrideAttrs (old: {
      src = old.src.overrideAttrs (_: {
        outputHash = "sha256-zO1/KUJe3LvYCGlwVpNg5uDwPRD0ql/7anErb7tywC0=";
      });
    });
  };
}

# bump: nix store prefetch-file <release-tarball-url> for the new hash
#
# DELIBERATELY PREBUILT (exception to the build-from-source rule): upstream is
# a Deno project (deno.json + deno.lock), and nixpkgs has no hermetic deno
# builder; a source build means hand-vendoring `deno compile` deps, which is
# more maintenance than one CLI is worth. revert condition: nixpkgs grows a
# real buildDenoPackage, then convert and drop this note.
{
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "linear-cli";
  version = "2.0.0";

  src = fetchurl {
    url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-aarch64-apple-darwin.tar.xz";
    hash = "sha256-Eh/h7ubZCyLnbk6Yy7YkR07s2XCkpMYi/U1QiJtX2sw=";
  };

  sourceRoot = "linear-aarch64-apple-darwin";

  installPhase = ''
    runHook preInstall
    install -Dm755 linear $out/bin/linear
    runHook postInstall
  '';

  meta = {
    description = "Linear from the command line (schpet/linear-cli)";
    homepage = "https://github.com/schpet/linear-cli";
    mainProgram = "linear";
    platforms = [ "aarch64-darwin" ];
  };
}

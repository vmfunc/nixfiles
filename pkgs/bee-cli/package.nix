# bee-cli: the Bee wearable's official CLI (@beeai/cli), packaged for the daylog.
# upstream ships only an npm tarball and locks with bun (bun.lock), which nixpkgs
# has no builder for, so this is the wrapper-package pattern: a two-line
# package.json depending on the exact published version, plus a package-lock.json
# generated once with `npm install --package-lock-only`, both vendored next to
# this file. bumping the version means bumping BOTH the version below and
# regenerating the lock, then taking the new npmDepsHash.
#
# only `bee sync` is used by the daylog (daylog-harvest reads its markdown
# output); the login/token dance stays manual and out of nix, since the token is
# an account secret and this repo has a public mirror.
{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs,
  autoPatchelfHook,
}:
buildNpmPackage {
  pname = "bee-cli";
  version = "0.7.3";

  # the "source" IS the wrapper manifest: npm resolves @beeai/cli from the
  # registry into node_modules, and there is nothing of our own to compile.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };

  npmDepsHash = "sha256-jIKO6HkHS89Nk+wfY5vvqcQ1AJg+YfWaMs6fH2PsbKg=";

  # nothing to build or test: the dependency ships prebuilt js.
  dontNpmBuild = true;
  dontNpmPrune = true;

  # bin/bee.js is only a shim: the real CLI is a bun-compiled, dynamically
  # linked generic-linux executable under dist/platforms/, which will not run on
  # nixos until its interpreter is patched. linux-only hook; on darwin the
  # mach-o binary needs nothing.
  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  # the stock install phase would install the WRAPPER (which has no bin); what
  # we want is the dependency's own bin, wrapped so it finds its node_modules.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/bee-cli" "$out/bin"
    cp -r node_modules "$out/lib/bee-cli/"
    makeWrapper ${lib.getExe nodejs} "$out/bin/bee" \
      --add-flags "$out/lib/bee-cli/node_modules/@beeai/cli/bin/bee.js"
    runHook postInstall
  '';

  meta = {
    description = "CLI client for the Bee wearable lifelogger";
    homepage = "https://docs.bee.computer/";
    license = lib.licenses.mit;
    mainProgram = "bee";
    platforms = lib.platforms.unix;
  };
}

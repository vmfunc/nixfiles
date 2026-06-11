{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  radare2,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "r2mcp";
  version = "1.8.4";

  src = fetchFromGitHub {
    owner = "radareorg";
    repo = "radare2-mcp";
    rev = finalAttrs.version;
    hash = "sha256-EbkEbTATKxBOKWVqKkHp6h/hg4VUW0TsgGxN9TRI+pc=";
  };

  # pkg-config puts r_core.pc on PKG_CONFIG_PATH (r2pm can't do this globally)
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ radare2 ];

  # darwin branch shells out to `brew --prefix`, gone in the sandbox; pkg-config
  # already gives us the r_core -I flags
  postPatch = ''
    substituteInPlace src/Makefile \
      --replace-fail 'CFLAGS += -I$(shell brew --prefix)/include' ""
  '';

  # build only the stdio server; root Makefile runs ./configure
  makeFlags = [
    "-C"
    "src"
    "CC=cc"
  ];
  buildFlags = [ "r2mcp" ];

  installPhase = ''
    runHook preInstall
    install -Dm755 src/r2mcp $out/bin/r2mcp
    runHook postInstall
  '';

  meta = {
    description = "Official radare2 MCP (Model Context Protocol) stdio server";
    homepage = "https://github.com/radareorg/radare2-mcp";
    license = lib.licenses.mit;
    mainProgram = "r2mcp";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
})

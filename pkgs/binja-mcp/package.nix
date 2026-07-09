# binja-mcp: the Claude-side stdio bridge to the Binary Ninja MCP plugin.
#
# two halves to this integration:
#   - SERVER: a Binary Ninja plugin (fosdickio/binary_ninja_mcp) that runs an HTTP
#     server inside BN on localhost:9009. it only uses BN's API + stdlib (no pip), so
#     home/modules/desktop/binary-ninja.nix symlinks THIS package's `src` straight into
#     BN's plugins dir. start it from BN: Plugins > MCP Server > Start Server.
#   - BRIDGE (this binary): a FastMCP stdio server Claude Code spawns; it relays MCP
#     tool calls to the :9009 HTTP server. deps are just requests + mcp.
#
# register with: claude mcp add binja -- binja-mcp   (claude config is hand-managed in
# ~/.claude.json, same as r2mcp/frida-mcp; nix can't write it). the BN binary must be
# OPEN with a target loaded and the server started for the tools to return anything.
{
  stdenv,
  fetchFromGitHub,
  python3,
  makeWrapper,
}:
let
  pythonEnv = python3.withPackages (ps: [
    ps.requests
    ps.mcp
  ]);
in
stdenv.mkDerivation {
  pname = "binja-mcp";
  version = "0-unstable-2026-06-26";

  src = fetchFromGitHub {
    owner = "fosdickio";
    repo = "binary_ninja_mcp";
    rev = "8c5134ee46e2bf44f9a4d846bd971c3e39b3e306";
    hash = "sha256-DqSJ2kQnQe/JPvWs8PL2ZEh4RPpBNRd3XVm20y1rQ9E=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # the bridge is a single script, no build step. wrap it with the python that carries
  # its runtime deps so `binja-mcp` is self-contained on PATH.
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 bridge/binja_mcp_bridge.py "$out/libexec/binja_mcp_bridge.py"
    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/binja-mcp" \
      --add-flags "$out/libexec/binja_mcp_bridge.py"
    runHook postInstall
  '';

  meta = {
    description = "stdio MCP bridge to the Binary Ninja MCP plugin (localhost:9009)";
    homepage = "https://github.com/fosdickio/binary_ninja_mcp";
    mainProgram = "binja-mcp";
    # bridge is pure-python, so it builds on both the macs and tuna. binary ninja
    # ships a linux build too (nixpkgs packages neither the free nor commercial one,
    # so the app is a manual install either way, see home/modules/desktop/binary-ninja.nix).
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
}

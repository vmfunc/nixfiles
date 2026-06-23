{
  lib,
  buildPythonApplication,
  setuptools,
  claude-agent-sdk,
  # anyio 4.13.0 drops sniffio from its deps (check-input only); pin it
  sniffio,
  makeWrapper,
  r2mcp,
  radare2,
  # ${claude-config}/skills/aarch64-triage/SKILL.md, threaded from pkgs/default.nix
  # (the input is private + token-fetched, so it is never vendored into this public tree)
  claudeSkill,
}:
buildPythonApplication {
  pname = "re-harness";
  version = "0.1.0";
  pyproject = true;

  # filter to module + pyproject so a stray case/ dir doesn't bust the hash
  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _type:
      let
        base = baseNameOf path;
      in
      base == "re_harness.py" || base == "pyproject.toml";
  };

  build-system = [ setuptools ];

  nativeBuildInputs = [ makeWrapper ];

  dependencies = [
    claude-agent-sdk
    sniffio
  ];

  doCheck = false;
  pythonImportsCheck = [ "re_harness" ];

  # bake the canonical skill next to the module so Path(__file__).with_name finds it
  postInstall = ''
    moduledir=$(dirname "$(find $out -name re_harness.py -path '*/site-packages/*' | head -n1)")
    install -Dm644 ${claudeSkill} "$moduledir/SKILL.md"
  '';

  # claude stays off PATH (unfree); the SDK finds the ambient one
  postFixup = ''
    wrapProgram $out/bin/re-harness \
      --prefix PATH : ${
        lib.makeBinPath [
          r2mcp
          radare2
        ]
      }
  '';

  meta = {
    description = "headless claude agent sdk batch RE triage runner (one agent per binary, r2mcp + /aarch64-triage)";
    longDescription = ''
      Loops a corpus of binaries, running one headless Claude agent per file
      with the AArch64 triage methodology and the radare2 MCP server. Each agent
      externalizes confirmed facts to a per-binary case/notes/findings.md and
      stops at a plateau; only binaries that cleared a finding are surfaced.

      GUARDRAIL: static/emulated triage only, it never executes a target. r2mcp
      can shell-escape, so detonate untrusted samples in the #pwn colima/lima VM,
      never on the host. Requires the `claude` CLI on PATH + configured auth.
    '';
    homepage = "https://github.com/vmfunc";
    mainProgram = "re-harness";
    platforms = [ "aarch64-darwin" ];
  };
}

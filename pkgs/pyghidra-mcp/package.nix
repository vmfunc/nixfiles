{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  makeWrapper,
  hatchling,
  ghidra,
  # pin jdk21, not the `jdk` alias (tracks latest LTS) which ghidra rejects
  jdk21,
  pyghidra,
  ghidrecomp,
  mcp,
  chromadb,
  click,
  click-option-group,
  python-dotenv,
  typer,
}:
buildPythonApplication rec {
  pname = "pyghidra-mcp";
  version = "0.2.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "clearbluejar";
    repo = "pyghidra-mcp";
    tag = "v${version}";
    hash = "sha256-iISjQU6qNgw3Yazg3EVBR/4uXz1B/lgyVdAec6PxkeQ=";
  };

  build-system = [ hatchling ];

  nativeBuildInputs = [
    makeWrapper
  ];

  pythonRelaxDeps = [
    "mcp"
    "chromadb"
    "pyghidra"
    "ghidrecomp"
    "click"
    "click-option-group"
  ];

  # mcp[cli] extra is just typer + python-dotenv, listed explicitly
  dependencies = [
    pyghidra
    ghidrecomp
    mcp
    chromadb
    click
    click-option-group
    python-dotenv
    typer
  ];

  pythonImportsCheck = [ "pyghidra_mcp" ];

  doCheck = false;

  # jdk21 on PATH: pyghidra's LaunchSupport execs `java` directly and the macOS stub exits non-zero
  postFixup = ''
    wrapProgram $out/bin/pyghidra-mcp \
      --set-default GHIDRA_INSTALL_DIR ${ghidra}/lib/ghidra \
      --set-default JAVA_HOME ${jdk21.home} \
      --prefix PATH : ${jdk21}/bin
  '';

  meta = {
    description = "MCP server exposing Ghidra reverse-engineering tools via pyghidra";
    homepage = "https://github.com/clearbluejar/pyghidra-mcp";
    license = lib.licenses.asl20;
    mainProgram = "pyghidra-mcp";
    platforms = [ "aarch64-darwin" ];
  };
}

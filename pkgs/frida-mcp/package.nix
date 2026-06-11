{
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonApplication rec {
  pname = "frida-mcp";
  version = "0.1.1-unstable-2025-05-29";

  # 0.1.1 has no matching git tag, pin the commit
  src = fetchFromGitHub {
    owner = "dnakov";
    repo = "frida-mcp";
    rev = "f8003c7de69ca8fc13a019f0c9b6abcc61b1717c";
    hash = "sha256-Qjh3FdwwrpsqzBNSJ46I49Iz5dpQWeaZtBWz6LD/2eI=";
  };

  pyproject = true;
  build-system = [ python3Packages.hatchling ];

  dependencies = [
    python3Packages.frida-python
    python3Packages.mcp
    python3Packages.pydantic
  ];

  doCheck = false;
  pythonImportsCheck = [ "frida_mcp" ];

  meta = {
    description = "stdio mcp server exposing frida dynamic instrumentation";
    homepage = "https://github.com/dnakov/frida-mcp";
    mainProgram = "frida-mcp";
    platforms = [ "aarch64-darwin" ];
  };
}

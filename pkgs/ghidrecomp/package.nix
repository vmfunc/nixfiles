{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  pyghidra,
}:
buildPythonPackage rec {
  pname = "ghidrecomp";
  version = "0.5.9";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "clearbluejar";
    repo = "ghidrecomp";
    tag = "v${version}";
    hash = "sha256-r8jMfK5oFvyd1eFgf4wJrDfhhUzGEUyPf+BmOrx2OSU=";
  };

  build-system = [ setuptools ];

  dependencies = [ pyghidra ];

  pythonImportsCheck = [ "ghidrecomp" ];

  doCheck = false;

  meta = {
    description = "Python command-line Ghidra decompiler (callgraph + BSim)";
    homepage = "https://github.com/clearbluejar/ghidrecomp";
    license = lib.licenses.gpl3Only;
    mainProgram = "ghidrecomp";
    platforms = [ "aarch64-darwin" ];
  };
}

# go toolchain + dev suite, on every host (macs + tuna). programs.go wires
# GOPATH + puts ~/go/bin on PATH; the rest is the lsp / lint / debug / test /
# vuln tooling azzie's go standards (goimports, go vet, golangci-lint) call for.
{ pkgs, ... }:
{
  programs.go.enable = true;

  home.packages = with pkgs; [
    gopls # language server
    gotools # goimports, godoc, etc
    go-tools # staticcheck
    golangci-lint # the meta-linter her standards run on every commit
    delve # dlv debugger
    govulncheck # vuln scanner
    gomodifytags
    gotests
    impl # generate interface stubs
  ];
}

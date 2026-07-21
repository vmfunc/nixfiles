# quaver's nix-config. run `just` to list recipes.
# nh picks darwin/nixos from the OS and the host from hostname.
# the checkout this justfile lives in, so `just` works from any clone location
# (~/mac-rice on the macs, ~/nixfiles on tuna, wherever)
flake := justfile_directory()

# list recipes
default:
    @just --list

# rebuild + switch this host (Discord presence via switch-rpc when installed;
# `command -v` gate keeps a never-activated host bootstrapping bare)
switch:
    @if [ "$(uname)" = "Darwin" ]; then cmd="nh darwin switch {{flake}}"; else cmd="nh os switch {{flake}}"; fi; \
    if command -v switch-rpc >/dev/null 2>&1; then exec switch-rpc -- $cmd; else exec $cmd; fi

# build only, no activation
build:
    @if [ "$(uname)" = "Darwin" ]; then nh darwin build {{flake}}; else nh os build {{flake}}; fi

# format every nix file
fmt:
    nix fmt

# local gate: fmt check + this host builds clean (full flake check needs per-platform CI)
check:
    nix build --no-link --print-build-logs ".#checks.$(nix eval --impure --raw --expr 'builtins.currentSystem').formatting"
    @if [ "$(uname)" = "Darwin" ]; then nh darwin build {{flake}}; else nh os build {{flake}}; fi

# update every flake input
update:
    nix flake update

# update one input, e.g. `just bump nixpkgs`
bump input:
    nix flake update {{input}}

# statix + deadnix + shellcheck. --inputs-from pins the tools to the flake's locked
# nixpkgs so local and CI run byte-identical linters (registry drift broke this once)
lint:
    nix run --inputs-from {{flake}} nixpkgs#statix -- check .
    nix run --inputs-from {{flake}} nixpkgs#deadnix -- --no-lambda-pattern-names --fail .
    nix run --inputs-from {{flake}} nixpkgs#shellcheck -- -S warning -e SC2154 sketchybar/plugins/*.sh # SC2154 = sketchybar's runtime $NAME/$SENDER

# secret scan before pushing public
scan dir=".":
    nix run --inputs-from {{flake}} nixpkgs#gitleaks -- dir {{dir}} --redact --verbose

# disclosure tripwire: every GHSA-SUBMIT-*.md needs a non-empty poc/, repro.txt, CVSS vector, file:line cite, zero hedge words
gate dir="~/pentest":
    nix run {{flake}}#gate-check -- {{dir}}

# gc old generations + dedup store
gc:
    nh clean all --keep 5 --keep-since 7d

# dev shell
dev:
    nix develop

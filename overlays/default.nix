{ inputs, ... }:
{
  # azzie's custom pkgs, surfaced on every host. tuna (linux) is her RE/kernel box
  # and wants the same cozy CLIs + toolchain as the macs, so this is no longer
  # darwin-gated. WHY the isDarwin test reads prev, not final: reading
  # final.stdenv to pick overlay keys recurses (the overlay would force itself).
  # linear-cli ships a prebuilt aarch64-apple-darwin binary, so it is dropped on
  # the linux hosts via removeAttrs; everything else builds cross-platform.
  additions =
    final: prev:
    let
      all = import ../pkgs {
        pkgs = final;
        inherit inputs;
      };
    in
    if prev.stdenv.hostPlatform.isDarwin then all else builtins.removeAttrs all [ "linear-cli" ];

  # emacs-overlay's whole package set (emacs-unstable*, emacsPackagesFor, ...) so the
  # doom module (home/modules/editor/emacs) can reach the pretest builds by attr name
  # on every host. version policy (31 pretest, not master) is documented in flake.nix.
  emacs = inputs.emacs-overlay.overlays.default;

  # upstream build workarounds. the darwin block stays gated: stale hashes that
  # only bite the macs plus a qemu pin for the macOS-only HVF assert (the pinned
  # hashes are platform-specific and mismatch on x86_64-linux otherwise).
  modifications =
    _final: prev:
    {
      # nhentai 0.5.25 pins chardet<6.0.0 but nixpkgs unstable moved to
      # 6.0.0.post1, so the runtime deps check fails the build. the pin is
      # upstream caution, not a real break; relax it. drop once prev.nhentai
      # builds without the override (nixpkgs bump of nhentai or chardet revert).
      nhentai = prev.nhentai.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "chardet" ];
      });

      # same class of break: mokuro 0.2.4 pins setuptools<81, nixpkgs unstable
      # ships 82.x. drop once prev.mokuro builds without the override.
      mokuro = prev.mokuro.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "setuptools" ];
      });

      # nixpkgs still ships gurk 0.9.3, whose bundled libsignal is too old for
      # signal's servers: device provisioning dies with HTTP 409 (gurk-rs #556,
      # our exact symptom). 0.10.0 (2026-07-19) carries a newer presage/libsignal.
      # explicit cargoDeps because overriding cargoHash alone would keep the old
      # vendor drv. drop once prev.gurk-rs is >= 0.10.0 and linking succeeds.
      gurk-rs = prev.gurk-rs.overrideAttrs (
        _:
        let
          src = prev.fetchFromGitHub {
            owner = "boxdot";
            repo = "gurk-rs";
            tag = "v0.10.0";
            hash = "sha256-6hDWNCULDwbHPKoemqW/xlofMY47nxxgduPzSz/FRx8=";
          };
        in
        {
          version = "0.10.0";
          inherit src;
          # 0.10.0 may have dropped the vendored .cargo/config.toml; -f keeps
          # the patch a no-op either way instead of failing the unpack.
          postPatch = "rm -f .cargo/config.toml";
          cargoDeps = prev.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "gurk-rs-0.10.0-vendor";
            hash = "sha256-COODj2eiH9MfnOpIrl1nTqsIn5JFZ+0ndizvORyCOjs=";
          };
        }
      );
    }
    // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
      # swift 5.10.1 is broken by cc-wrapper's new -mtls-dialect=gnu2 (see the
      # nixpkgs-swift input comment). deadbeef only needs libdispatch, so pin
      # just that attr to the pre-bump rev already in tuna's store.
      inherit
        (import inputs.nixpkgs-swift {
          inherit (prev.stdenv.hostPlatform) system;
        })
        swift-corelibs-libdispatch
        ;

      # gobuster 3.8.x's nixpkgs build emits a stray `vhs` binary next to `gobuster`
      # (not one of its brute modes), which collides with charmbracelet's vhs
      # (home/modules/cli/packages.nix) in the home.packages buildEnv and fails the
      # switch. gobuster proper is the only wanted binary; drop the stray so both
      # packages coexist. remove once nixpkgs stops shipping the extra binary.
      gobuster = prev.gobuster.overrideAttrs (o: {
        postInstall = (o.postInstall or "") + ''
          rm -f "$out/bin/vhs"
        '';
      });
    }
    // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
      # stale go vendorHash upstream; drop once prev.sif builds without the override
      sif = prev.sif.overrideAttrs (_: {
        vendorHash = "sha256-yoQ1E0EwNHAACUOZnAayflB2m9uXE4/UbPse7GP+61Q=";
      });

      # john "rolling" ships a stale source hash; drop once prev.john's src fetches clean
      john = prev.john.overrideAttrs (old: {
        src = old.src.overrideAttrs (_: {
          outputHash = "sha256-zO1/KUJe3LvYCGlwVpNg5uDwPRD0ql/7anErb7tywC0=";
        });
      });

      # qemu 11.x HVF backend SIGABRTs in hvf_arch_init_vcpu on macOS 26.5.1
      # (assert HV_SYS_REG_SMCR_EL1 == KVMID_TO_HVF(...), the SME sysreg mapping),
      # crash-looping the linux-builder. 10.2.2 predates that code and boots fine.
      # pull qemu from the pinned pre-bump nixpkgs; revert when upstream fixes it.
      inherit
        (import inputs.nixpkgs-qemu {
          inherit (prev.stdenv.hostPlatform) system;
        })
        qemu
        ;
    };
}

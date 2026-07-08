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

  # darwin-only build workarounds: stale upstream hashes that only bite the macs,
  # plus a qemu pin for the macOS-only HVF assert. gate to darwin so the linux
  # hosts use upstream nixpkgs, where sif/john/qemu build clean (the pinned hashes
  # are platform-specific and mismatch on x86_64-linux otherwise).
  modifications =
    _final: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
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

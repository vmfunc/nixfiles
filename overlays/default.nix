{ inputs, ... }:
{
  # gate on prev.stdenv, reading final.stdenv to pick overlay keys recurses
  additions =
    final: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin (
      import ../pkgs {
        pkgs = final;
        inherit inputs;
      }
    );

  modifications = _final: prev: {
    # stale go vendorHash upstream
    sif = prev.sif.overrideAttrs (_: {
      vendorHash = "sha256-yoQ1E0EwNHAACUOZnAayflB2m9uXE4/UbPse7GP+61Q=";
    });

    # john "rolling" ships a stale source hash
    john = prev.john.overrideAttrs (old: {
      src = old.src.overrideAttrs (_: {
        outputHash = "sha256-zO1/KUJe3LvYCGlwVpNg5uDwPRD0ql/7anErb7tywC0=";
      });
    });

    # qemu 11.x HVF backend SIGABRTs in hvf_arch_init_vcpu on macOS 26.5.1
    # (assert HV_SYS_REG_SMCR_EL1 == KVMID_TO_HVF(...), the SME sysreg mapping),
    # crash-looping the linux-builder. 10.2.2 predates that code and boots fine.
    # Pull qemu from the pinned pre-bump nixpkgs; revert when upstream fixes it.
    inherit
      (import inputs.nixpkgs-qemu {
        inherit (prev.stdenv.hostPlatform) system;
      })
      qemu
      ;
  };
}

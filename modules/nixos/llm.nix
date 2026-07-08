# local llm stack, gated behind rice.llm.enable (default off). the whole reason
# this APU is interesting: 64GB unified memory means gfx1151 can address a large
# slice as "VRAM" and run 30-70B models. WHY llama.cpp Vulkan as the primary path:
# on gfx1151 RADV/Vulkan is the pragmatic best-throughput backend and needs no
# rocm install; ollama's vendored llama.cpp lags upstream. rocm stays a secondary
# toolbox (HSA_OVERRIDE_GFX_VERSION below) for long-context / pytorch experiments.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.llm;
in
{
  options.rice.llm.enable = lib.mkEnableOption "local llm stack (llama.cpp vulkan + ollama)";

  config = lib.mkIf cfg.enable {
    # ollama on auto acceleration; the heavy lifting is the standalone llama.cpp
    # vulkan build, which offloads to the iGPU directly.
    services.ollama.enable = true;

    environment.systemPackages = [
      (pkgs.llama-cpp.override { vulkanSupport = true; })
    ];

    # gfx1151 is not in rocm's official matrix; this override is what rocm builds
    # need to target it. harmless for the vulkan path, set once for both.
    environment.sessionVariables.HSA_OVERRIDE_GFX_VERSION = "11.5.1";
  };
}

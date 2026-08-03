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
  options.rice.llm = {
    enable = lib.mkEnableOption "local llm stack (llama.cpp vulkan + ollama)";
    # serve ollama to the rest of the fleet (obsidian copilot "ask my vault" on
    # the laptops, any tailnet client). WHY tailnet-only: ollama has no auth, so
    # its api is a wide-open door; bind it and open the port ONLY on tailscale0,
    # the same posture as rice.mediaServers (media-servers.nix). off by default,
    # on for the always-on box (tuna) that actually has the memory to serve.
    serve = lib.mkEnableOption "expose ollama to the tailnet (no auth, tailscale0 only)";
  };

  config = lib.mkIf cfg.enable {
    # ollama on auto acceleration; the heavy lifting is the standalone llama.cpp
    # vulkan build, which offloads to the iGPU directly.
    services.ollama = {
      enable = true;
      # default is 127.0.0.1; bind all interfaces ONLY when serving, and let the
      # tailscale0-only firewall hole below be the thing that restricts reach.
      host = lib.mkIf cfg.serve "0.0.0.0";
      # obsidian's renderer is an app:// origin, so ollama's CORS check rejects
      # its api calls unless that origin is allowlisted. required for the copilot
      # "ask my vault" plugin on the laptops to talk to this box.
      environmentVariables = lib.mkIf cfg.serve {
        OLLAMA_ORIGINS = "app://obsidian.md*";
      };
    };

    # the tailnet door for ollama's 11434. interface-scoped so it never opens on
    # the LAN/WAN, matching the box's tailscale-transport posture. clients reach
    # it by magicdns name (http://tuna:11434).
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkIf cfg.serve [ 11434 ];

    environment.systemPackages = [
      (pkgs.llama-cpp.override { vulkanSupport = true; })
    ];

    # gfx1151 is not in rocm's official matrix; this override is what rocm builds
    # need to target it. harmless for the vulkan path, set once for both.
    environment.sessionVariables.HSA_OVERRIDE_GFX_VERSION = "11.5.1";
  };
}

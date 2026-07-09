# mangohud performance overlay, themed to the active "blood" lain palette.
# tuna-scoped (tracks the rice.gaming role, like vkbasalt.nix), not in the
# desktop-linux profile. NOT session-wide: the hud only appears when a game is
# launched with mangohud (steam launch option `mangohud %command%`, or MANGOHUD=1),
# so it costs nothing on the desktop. colors are hex WITHOUT the leading '#'
# (mangohud's own format), pulled by hand from the theme specialArg because
# mangohud has no catppuccin/native theme integration.
{ theme, ... }:
let
  # strip the '#' nix theme hexes carry; mangohud wants bare RRGGBB.
  hex = c: builtins.substring 1 6 theme.palette.${c};
in
{
  programs.mangohud = {
    enable = true;
    settings = {
      # what to show: the useful subset, not the kitchen sink. gpu/cpu load +
      # temp, vram/ram, fps + a frametime graph, frame timing, and gamemode
      # state so a glance confirms the renice/gpu-pin actually engaged.
      gpu_stats = true;
      gpu_temp = true;
      gpu_load_change = true;
      cpu_stats = true;
      cpu_temp = true;
      cpu_load_change = true;
      vram = true;
      ram = true;
      fps = true;
      frametime = true;
      frame_timing = true;
      gamemode = true;
      # amd: the RADV/strix-halo bits worth watching.
      throttling_status = true;
      gpu_core_clock = true;
      gpu_mem_clock = true;

      # placement + feel: top-left, compact, semi-transparent over the base color
      # so it reads on both bright and dark scenes without blocking the view.
      position = "top-left";
      font_size = 20;
      background_alpha = "0.55";
      round_corners = 8;
      toggle_hud = "Shift_R+F12";
      toggle_logging = "Shift_R+F11";

      # blood palette. mauve = gpu, muted-blue = cpu, plum-rose = fps/engine,
      # sage = frametime, near-black base for the panel, warm text.
      background_color = hex "base";
      text_color = hex "text";
      gpu_color = hex "mauve";
      cpu_color = hex "blue";
      vram_color = hex "yellow";
      ram_color = hex "yellow";
      engine_color = hex "red";
      fps_color_change = true;
      frametime_color = hex "green";
      media_player_color = hex "text";
      wine_color = hex "mauve";
    };
  };
}

# obs studio (full nixpkgs source build, no repackaged binary anywhere in the
# chain), recording/streaming on the niri desktop. screen capture rides the
# pipewire screencast portal that niri-flake wires at the system layer
# (modules/nixos/desktop-portal.nix links the portal dirs), so the built-in
# "Screen Capture (PipeWire)" source works with no wlrobs needed.
# deps: consumed via home/profiles/desktop-linux.nix. hw encode is native
# ffmpeg-vaapi on the strix-halo iGPU (hosts/tuna wires libva), no obs-vaapi
# gstreamer detour needed. virtual camera is deliberately absent: it needs the
# v4l2loopback module built against tuna's bleeding-edge kernel, a system-layer
# change to take on the day it is actually wanted.
{ pkgs, ... }:
{
  programs.obs-studio = {
    enable = true;

    plugins = with pkgs.obs-studio-plugins; [
      # per-application audio capture via pipewire, the sane way to split
      # game/voice/music tracks instead of grabbing the whole mix.
      obs-pipewire-audio-capture
      # vulkan/opengl game capture (the wayland "game capture" source). launch
      # the game through `obs-gamecapture %command%` or OBS_VKCAPTURE=1.
      obs-vkcapture
    ];
  };

  # the vkcapture *layer* half must sit in the game's environment, not just
  # inside the obs wrapper: putting the plugin package in the profile lands its
  # vulkan implicit-layer manifest + obs-gamecapture wrapper on XDG_DATA_DIRS/PATH.
  home.packages = [ pkgs.obs-studio-plugins.obs-vkcapture ];
}

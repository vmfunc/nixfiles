# mpv, the one video pipeline everything funnels into (streamlink live, yt-dlp
# VOD, ani-cli, local files). moved out of the modules/nixos/apps.nix bare list so
# it can carry config + scripts. uosc replaces the stock OSC; mpris wires playback
# into the existing nowplaying-rpc-linux / wired-sound / scrobble stack. colored by
# hand from theme.palette (blood variant; catppuccin.enable is false here).
# deps: consumed via home/profiles/desktop-linux.nix. pairs with streamlink.nix +
# yt-dlp.nix (the JP-tv sources).
{ pkgs, theme, ... }:
{
  programs.mpv = {
    enable = true;

    scripts = with pkgs.mpvScripts; [
      uosc # modern OSC/menu UI (needs osc=no + border=no below)
      thumbfast # hover thumbnails for uosc's timeline
      mpris # MPRIS so the now-playing/scrobble stack sees mpv
      quality-menu # switch HLS variants live (e.g. NHK master m3u8 1M/4M)
    ];

    config = {
      # uosc owns the UI, so the stock on-screen-controller + window border off.
      osc = "no";
      border = "no";

      # RADV / strix-halo iGPU: gpu-next + safe hwdec. auto-safe avoids the
      # decoders that glitch on this stack while still offloading the common ones.
      vo = "gpu-next";
      hwdec = "auto-safe";
      profile = "high-quality";

      # sane defaults: remember position, big cache for VOD, jp+eng sub/audio pref.
      save-position-on-quit = true;
      keep-open = true;
      cache = "yes";
      demuxer-max-bytes = "150MiB";
      slang = "jpn,ja,eng,en";
      alang = "jpn,ja,eng,en";

      # readable subs over the blood palette (border keeps them legible on any scene).
      sub-font-size = 40;
      sub-color = "#${builtins.substring 1 6 theme.palette.text}";
      sub-border-color = "#${builtins.substring 1 6 theme.palette.crust}";
      sub-border-size = 2;
      osd-color = "#${builtins.substring 1 6 theme.palette.mauve}";
    };

    # live-stream profile: no on-disk cache buildup, low latency, tuned for
    # streamlink/HLS (NHK World, youtube-live). invoke with `--profile=live`.
    profiles = {
      live = {
        cache = "no";
        demuxer-max-bytes = "32MiB";
        cache-secs = 2;
        profile-desc = "low-latency live streams";
      };
    };
  };
}

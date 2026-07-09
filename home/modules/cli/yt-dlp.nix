# yt-dlp: VOD / catch-up downloader + archival, and the backend mpv shells out to
# for ytdl playback (it was never actually installed despite mpv depending on it,
# this closes that gap). defaults tuned for japanese: embed JP subs, sponsorblock,
# HLS. deps: pairs with mpv.nix / streamlink.nix.
{ ... }:
{
  programs.yt-dlp = {
    enable = true;
    settings = {
      embed-subs = true;
      embed-metadata = true;
      sub-langs = "ja,en";
      # keep the mkv container so embedded JP subs + chapters survive.
      merge-output-format = "mkv";
      sponsorblock-mark = "all";
    };
  };
}

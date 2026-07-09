# streamlink: pull live HLS/DASH into mpv. the workhorse for japanese tv, NHK
# World-Japan (free worldwide), youtube-live JP news/vtubers, and the abematv /
# nicolive first-party plugins. deps: home/modules/desktop/mpv.nix (the player).
# usage: `streamlink <url> best`, or `streamlink --player-args=--profile=live <url> best`
# for the low-latency mpv profile.
{ pkgs, ... }:
{
  programs.streamlink = {
    enable = true;
    settings = {
      player = "${pkgs.mpv}/bin/mpv";
      default-stream = "best";
    };
  };

  # geo-lock reality: radiko / TVer / ABEMA / Niconico-Live IP-lock to a japanese
  # residential/mobile IP; the plugins work but hit a geo wall from the US. NHK
  # World + youtube-live are ungated and the daily driver.
  # TODO(deploy): for the geo-locked tier, route through a JP tailscale exit-node
  # (tailscale is already in the tree) or a JP residential proxy. datacenter JP
  # VPNs are fingerprinted and blocked (radiko especially). no package fixes this.
}

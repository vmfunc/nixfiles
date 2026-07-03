{ config, ... }:
{
  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/mac-rice";
  };
}

# desktop apps for the linux hosts (currently tuna). system-level so they land
# in PATH + get .desktop entries without threading each through home. the terminal
# rice (nvim, yazi, nushell, etc.) stays in home/; this is the GUI/creature-comfort
# layer. gaming is separate (modules/nixos/gaming.nix), llm too (llm.nix).
{ pkgs, inputs, ... }:
{
  environment.systemPackages =
    (with pkgs; [
      # chat
      vesktop # discord client (the mac runs this too)
      element-desktop # matrix
      cinny-desktop # matrix (the mac aerospace assigns "Cinny" to a workspace)

      hyfetch # pride-flag fetch for repo screenshots (fastfetch lives in home)
      spotify
      mpv # video
      imv # wayland image viewer
      prismlauncher # minecraft / modded launcher
      obs-studio # capture/stream
      pavucontrol # pipewire mixer
      nautilus # a GUI file manager alongside yazi
      wl-clipboard
    ])
    ++ [
      # zen browser, azzie's daily driver (linux build from the flake input)
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}

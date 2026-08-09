# tuna desktop app bundle: the GUI + extra CLI apps azzie wants on the Framework
# Desktop that aren't already carried by a dedicated module or profile. TUNA-ONLY
# (imported from home/tuna.nix), so the blast radius is just this box, not the
# shared linux-desktop profile (minnow/guppy) and not the macs.
#
# deliberately a bulk list, same species as home/modules/cli/packages.nix and
# profiles/security.nix: these are plain installs with no per-program config to
# own, so the "one program per file" rule doesn't buy anything here. anything that
# grows real config (keybinds, theming, a service) should graduate to its own
# module under home/modules/<area>/ and drop out of this list.
#
# NOT here because already provided elsewhere: neovim/lazygit/zellij/cava/delta/
# direnv/just/rg/fd/bat/eza/fzf/zoxide/fastfetch/btop (base.nix + core modules),
# bitwarden-desktop/obsidian/kdeconnect/mpv/obs-studio/yt-dlp (desktop-linux
# modules), radare2/nmap/jadx/apktool/aflplusplus (profiles/security.nix), and
# cake-wallet (its own module, packaged from the upstream tarball).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # fedi / mastodon
    kdePackages.tokodon # kde-native, primary
    tuba # gtk alt

    # reverse engineering / security (GUI + tools not in security.nix's set)
    ghidra
    cutter # rizin gui
    rizin
    imhex # hex editor
    gef # gdb enhancer; pwndbg is NOT in nixpkgs, gef is the packaged stand-in
    gdb
    frida-tools # dynamic instrumentation cli (security.nix ships frida-mcp on darwin only)
    wireshark # the qt gui; security.nix carries wireshark-cli/tshark for headless
    virt-manager # qemu/kvm frontend
    qemu # microVM oracle work

    # terminal
    kdePackages.yakuake # plasma dropdown term

    # editors / dev
    helix
    vscodium
    hyfetch # the plural fastfetch
    nil # nix language server
    nixpkgs-fmt
    nix-tree
    nvd # store diff viewer (nh wraps it; this puts `nvd` on PATH directly)
    nix-output-monitor

    # comms
    nheko # qt matrix
    vesktop # discord + vencord, fixes wl screenshare
    halloy # rust irc
    kdePackages.konversation # kde irc classic
    simplex-chat-desktop # simplex desktop (attr is simplex-chat-desktop)

    # selfhost companions (collar.sh)
    syncthingtray
    localsend
    kdePackages.kleopatra # pgp/certs
    rclone

    # music (hi-fi + label)
    strawberry # flac-hoarder library player
    whipper # accuraterip cd ripping
    picard # musicbrainz tagging
    easytag
    kdePackages.k3b
    mixxx # dj, for the label
    reaper # daw

    # media
    haruna
    freetube # point at the invidious instance

    # gaming
    xivlauncher # goatcorp, dalamud included

    # plasma / desktop
    kdePackages.filelight
    kdePackages.kate
    kdePackages.okular
    kdePackages.spectacle
    kdePackages.ark
    qbittorrent
    tor-browser
  ];
}

{ pkgs, lib, ... }:
{
  home.packages =
    with pkgs;
    [
      sif # github.com/vmfunc/sif
      nmap
      rustscan
      ffuf
      gobuster
      feroxbuster
      sqlmap
      john
      ncrack # thc-hydra/medusa pull samba, fails on darwin
      nikto
      amass
      subfinder
      httpx
      nuclei
      naabu
      dnsx
      katana
      radare2
      binwalk
      exiftool
      hashcat
      hashid
      seclists
      metasploit
      # burpsuite is linux-only in nixpkgs, use the native macos app
      wireshark-cli # tshark
      termshark
      tcpdump
      socat
      netcat-gnu
    ]
    # net-HUDs / "the Wired is always on" ambient monitors. linux-only: wavemon
    # (wireless-tools), netscanner (raw wifi/arp) and kmon (kernel modules) do not
    # build on darwin, so guard the whole block rather than split it.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (
      with pkgs;
      [
        trippy # traceroute + ping TUI (mtr successor)
        bandwhich # per-process / per-connection bandwidth monitor
        netscanner # ratatui recon TUI (wifi/arp/port)
        wavemon # ncurses wifi signal monitor
        kmon # kernel-module activity monitor, pairs with the OOT LKM work
      ]
    );
}

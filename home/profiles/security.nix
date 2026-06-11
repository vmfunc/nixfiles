{ pkgs, ... }:
{
  home.packages = with pkgs; [
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
  ];
}

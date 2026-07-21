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

      # web + dns recon extensions to the existing projectdiscovery stack
      mitmproxy # intercepting proxy TUI; the linux stand-in for the macos burp
      doggo # modern dig, JSON output; DNS recon companion to dnsx
      whatweb # web-tech fingerprinting (cms/framework/server)
      dalfox # XSS scanner, pairs with the katana/httpx crawl chain
      interactsh # OOB (dns/http) interaction server, the SSRF/blind-injection ear next to nuclei

      # binary analysis / RE (build cross-platform; runtime may degrade on darwin)
      lief # parse/modify elf/pe/mach-o programmatically
      yara-x # rust rewrite of yara, malware pattern matching
      capa # identify capabilities in executables/shellcode/dylibs
      flare-floss # auto-deobfuscate stack/tight strings from malware

      # exploit-dev / ctf / fuzzing
      radamsa # black-box mutation fuzzer / test-case generator

      # forensics
      sleuthkit # disk image / filesystem forensics (mmls, fls, icat)

      # network recon / pentest
      responder # llmnr/nbt-ns/mdns poisoner for hash capture
      wapiti # black-box web app vuln scanner
      aircrack-ng # wifi wep/wpa capture + crack suite

      # stego / mobile / containers
      zsteg # detect lsb stego in png/bmp
      jadx # dex -> java decompiler for apk RE
      apktool # apk disassemble/rebuild (smali + resources)
      trivy # container/fs/iac/sbom vuln + misconfig scanner
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
        masscan # internet-scale SYN scanner; the wide-net complement to nmap/naabu
        bettercap # network MITM/attack swiss-army (arp/dns/ble/wifi), linux-only

        # decompiler / packer id (linux-only in nixpkgs)
        retdec # retargetable machine-code decompiler
        detect-it-easy # packer/compiler/protector detection (die)

        # hardening audit + coverage fuzzers
        checksec # binary hardening audit (relro/nx/pie/canary)
        aflplusplus # coverage-guided fuzzer (cmplog + qemu/frida modes)
        honggfuzz # persistent coverage fuzzer w/ hw feedback

        # web
        zap # owasp zap intercepting proxy + active scanner

        # linux-only in nixpkgs (elfutils / linux-only deps): exploit-dev,
        # memory forensics, AD sweep, mass scan, OSINT enum
        pwninit # ctf pwn setup: patchelf the libc, drop a solve template
        volatility3 # memory-dump forensics framework
        netexec # crackmapexec successor: smb/ldap/winrm sweep + creds
        zmap # single-packet internet-wide port scanner
        maigret # username -> account enumeration across sites
      ]
    );
}

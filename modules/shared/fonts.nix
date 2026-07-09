{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    maple-mono.NF
    sketchybar-app-font

    # lain / copland-os crt faces. cozette + tamzen = bitmap terminal mono,
    # vt323 / orbitron / share tech mono (via google-fonts) = crt/hud display.
    cozette
    tamzen
    departure-mono
    vt323
    orbitron
    # only Share Tech Mono, not the whole Google Fonts catalog (closure bloat on every host)
    (google-fonts.override { fonts = [ "ShareTechMono" ]; })

    # CJK coverage so japanese renders instead of tofu (JP PSO2, JP tv, immersion
    # tooling). noto = the full-coverage workhorse, source-han = adobe's pan-CJK
    # with a proper monospace variant for the terminal.
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    source-han-sans
    source-han-mono
  ];
}

{ ... }:
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo.type = "none";
      display.color.keys = "38;2;198;160;246";
      modules = [
        "title"
        "separator"
        "os"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "wm"
        "terminal"
        "memory"
        "break"
        "colors"
      ];
    };
  };
}

{ ... }:
{
  # theme from the global catppuccin module
  programs.bat = {
    enable = true;
    config = {
      style = "numbers,changes,header";
      map-syntax = [
        "*.s:Assembly"
        "*.asm:Assembly"
      ];
    };
  };
}

{ ... }:
{
  programs.tealdeer = {
    enable = true;
    settings = {
      updates.auto_update = true;
      display = {
        compact = false;
        use_pager = false;
      };
      # ansi colour names only, no hex
      style = {
        command_name.foreground = "magenta";
        example_text.foreground = "green";
        example_code.foreground = "blue";
        example_variable = {
          foreground = "cyan";
          italic = true;
        };
      };
    };
  };
}

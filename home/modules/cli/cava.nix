{ theme, ... }:
{
  programs.cava = {
    enable = true;
    settings = {
      general.framerate = 60;
      color = {
        gradient = 1;
        gradient_count = 4;
        gradient_color_1 = "'${theme.palette.blue}'";
        gradient_color_2 = "'${theme.palette.sky}'";
        gradient_color_3 = "'${theme.palette.mauve}'";
        gradient_color_4 = "'${theme.palette.pink}'";
      };
    };
  };
}

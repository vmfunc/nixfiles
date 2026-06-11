{ theme, ... }:
let
  paletteName = "catppuccin_${theme.flavor}";
in
{
  catppuccin.starship.enable = false;

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      palette = paletteName;

      format = builtins.concatStringsSep "" [
        "[](surface0)"
        "$os$username"
        "[](bg:blue fg:surface0)"
        "$directory"
        "[](fg:blue bg:surface1)"
        "$git_branch$git_status"
        "[](fg:surface1 bg:surface0)"
        "$nodejs$python$rust$golang$nix_shell"
        "[](fg:surface0)"
        "$fill"
        "$cmd_duration$status$jobs$time"
        "$line_break$character"
      ];

      os = {
        disabled = false;
        style = "bg:surface0 fg:text";
        symbols.Macos = "";
      };
      username = {
        show_always = true;
        style_user = "bg:surface0 fg:mauve";
        style_root = "bg:surface0 fg:red";
        format = "[ $user ]($style)";
      };
      directory = {
        style = "fg:crust bg:blue";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          "Documents" = "󰈙";
          "Downloads" = "";
          "Music" = "";
          "Pictures" = "";
        };
      };
      git_branch = {
        symbol = "";
        style = "bg:surface1 fg:mauve";
        format = "[ $symbol $branch ]($style)";
      };
      git_status = {
        style = "bg:surface1 fg:red";
        format = "[$all_status$ahead_behind ]($style)";
      };
      nodejs = {
        symbol = "";
        style = "bg:surface0 fg:green";
        format = "[ $symbol ($version) ]($style)";
      };
      python = {
        symbol = "";
        style = "bg:surface0 fg:yellow";
        format = "[ $symbol ($version) ]($style)";
      };
      rust = {
        symbol = "";
        style = "bg:surface0 fg:peach";
        format = "[ $symbol ($version) ]($style)";
      };
      golang = {
        symbol = "";
        style = "bg:surface0 fg:sky";
        format = "[ $symbol ($version) ]($style)";
      };
      nix_shell = {
        symbol = "";
        style = "bg:surface0 fg:blue";
        format = "[ $symbol $state ]($style)";
      };
      fill.symbol = " ";
      cmd_duration = {
        min_time = 500;
        style = "fg:yellow";
        format = "[  $duration ]($style)";
      };
      status = {
        disabled = false;
        style = "fg:red";
        symbol = "✖ ";
        format = "[ $symbol$status ]($style)";
        map_symbol = true;
      };
      jobs = {
        symbol = " ";
        style = "fg:peach";
        number_threshold = 1;
        format = "[ $symbol$number ]($style)";
      };
      time = {
        disabled = false;
        time_format = "%H:%M";
        style = "fg:subtext0";
        format = "[ $time ]($style)";
      };
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold mauve)";
      };

      palettes.${paletteName} = theme.palette;
    };
  };
}

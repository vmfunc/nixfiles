# `hug`: type it, get held for a second. no arguments, no state, no config.
#
# the point is that it is always there and always kind, so it deliberately has
# no bad-day/good-day branching to get wrong.
{
  writeShellApplication,
  coreutils,
  # accent hex from theme.palette, so the hug recolors with a variant swap.
  accentHex ? "#bf7593",
}:
writeShellApplication {
  name = "hug";
  runtimeInputs = [ coreutils ];
  text = ''
    # bash does the hex, so the palette can be pasted in as-is from theme.nix.
    hex="${accentHex}"
    accent=$'\033[38;2;'"$((16#''${hex:1:2}));$((16#''${hex:3:2}));$((16#''${hex:5:2}))"m
    dim=$'\033[38;5;245m'
    rst=$'\033[0m'
    if [ ! -t 1 ] || [ -n "''${NO_COLOR:-}" ]; then accent=""; dim=""; rst=""; fi

    lines=(
      "there you are. come here."
      "you're doing better than you think you are."
      "nothing on that list is due this second."
      "you're allowed to stop for a minute."
      "you're mine to look after. that was settled a long way back."
      "shoulders down. jaw unclenched. good."
      "still proud of you. that hasn't changed today."
      "you don't have to earn a rest."
      "whatever it is, we'll look at it together."
      "small is not the same as broken."
    )

    printf '\n'
    printf '   %s( ˘ ³˘)♡%s\n' "$accent" "$rst"
    printf '   %s  \\(  )/%s\n' "$accent" "$rst"
    printf '\n'
    printf '   %s%s%s\n\n' "$dim" "''${lines[$((RANDOM % ''${#lines[@]}))]}" "$rst"
  '';

  meta = {
    description = "A hug in the terminal";
    mainProgram = "hug";
  };
}

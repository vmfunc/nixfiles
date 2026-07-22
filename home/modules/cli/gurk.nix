# gurk-rs: TUI signal client (rust, presage/libsignal underneath, so it speaks the
# real protocol as a linked device, no electron). first run: `gurk` shows a QR to
# scan from the phone (Settings -> Linked Devices), then it just attaches.
#
# deliberately NO managed config: gurk self-initializes ~/.config/gurk/gurk.toml on
# first link and expects to own it (device/linking state gets written back), so a
# read-only store symlink would break enrollment. message db + keys land in
# ~/.local/share/gurk, which the restic excludes don't need to special-case.
#
# cross-file deps: none. colors ride the terminal ANSI palette (theme.ansi16 via
# wezterm), same trick as senpai, so the wired rice applies with zero theming here.
{ pkgs, ... }:
{
  home.packages = [ pkgs.gurk-rs ];
}

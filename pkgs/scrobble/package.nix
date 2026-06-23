{
  python3,
  writeShellApplication,
}:
# stdlib-only python (urllib + hashlib), so no pip deps: just put python3 on PATH
# and run the script from its store path.
writeShellApplication {
  name = "scrobble";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 ${./scrobble.py} "$@"
  '';
  meta = {
    description = "headless apple music -> last.fm scrobbler (osascript polling, macOS 26 safe)";
    mainProgram = "scrobble";
  };
}

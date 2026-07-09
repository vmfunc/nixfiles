# japanese tv commands, all funneling into the hand-tuned mpv (mpv.nix, --profile=live):
#   jptv            - pick a JP channel (fzf) and play it
#   jptv-translate  - same, but with a LIVE whisper JA->EN subtitle overlay
#                     (whisper-stream, GPU, continuous, ~3s lag off the audio monitor)
#   strm <url>      - play any streamable url via streamlink (imagemagick owns `stream`)
# source is the iptv-org JP channel list (maintained + self-updating, so the HLS
# urls stay fresh) plus NHK World-Japan (english broadcast, its own CDN).
# subtitles: domestic JP channels are raw broadcast HLS with NO english track, so
# jptv-translate is the english path for them (NHK World is already english). the
# whisper overlay is EXPERIMENTAL: ~10s chunked latency, rough quality.
# deps: mpv.nix (the player + live profile), streamlink.nix.
{ pkgs, ... }:
let
  jpList = "https://iptv-org.github.io/iptv/countries/jp.m3u";
  nhkUrl = "https://masterpl.hls.nhkworld.jp/hls/w/live/smarttv.m3u8";

  # whisper ggml base model: multilingual + translate-capable, the latency/quality
  # sweet spot for LIVE tv. override WHISPER_MODEL with a small/medium ggml for
  # better JA->EN at the cost of lag. fetched by hash, cached in the store.
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin";
    hash = "sha256-YO1bw90U7qhWST0zQ0m0BXgt3K8AKNS130CINF+6Lv4=";
  };

  # shared resolver. jptv_fetch prints "name<TAB>url" for every channel (NHK World
  # prepended, since it is not in the iptv-org country list). jptv_pick turns an
  # arg into one selection: a raw http url passes through, a name filters, empty
  # opens fzf. --list is handled by the wrappers directly (not through jptv_pick,
  # so its output isn't swallowed by command substitution).
  resolveFn = ''
    jptv_fetch() {
      local list="''${JPTV_LIST:-${jpList}}" m3u
      m3u="$(curl -fsSL --max-time 20 "$list")" || { echo "channel list fetch failed (network?)" >&2; return 1; }
      printf 'NHK World-Japan (EN)\t${nhkUrl}\n'
      printf '%s\n' "$m3u" | awk -F',' '/^#EXTINF/{name=$NF; getline url; gsub(/\r/,"",url); print name "\t" url}'
    }
    jptv_pick() {
      case "''${1:-}" in
        http*://*) printf 'stream\t%s\n' "$1"; return 0 ;;
      esac
      local all sel
      all="$(jptv_fetch)" || return 1
      if [ -n "''${1:-}" ]; then
        sel="$(printf '%s\n' "$all" | grep -iF -- "$1" | head -1)"
      else
        sel="$(printf '%s\n' "$all" | fzf --delimiter='\t' --with-nth=1 --prompt='jp tv> ')"
      fi
      [ -n "''${sel:-}" ] || { echo "no channel matched" >&2; return 1; }
      printf '%s\n' "$sel"
    }
  '';

  jptv = pkgs.writeShellApplication {
    name = "jptv";
    runtimeInputs = with pkgs; [
      curl
      gawk
      fzf
      mpv
      coreutils
      gnugrep
    ];
    text = ''
      ${resolveFn}
      if [ "''${1:-}" = "--list" ]; then jptv_fetch | cut -f1; exit 0; fi
      sel="$(jptv_pick "''${1:-}")" || exit 1
      name="$(printf '%s' "$sel" | cut -f1)"
      url="$(printf '%s' "$sel" | cut -f2)"
      echo "playing: $name"
      exec mpv --profile=live --force-media-title="$name" "$url"
    '';
  };

  jptvTranslate = pkgs.writeShellApplication {
    name = "jptv-translate";
    runtimeInputs = with pkgs; [
      curl
      gawk
      fzf
      mpv
      whisper-cpp
      socat
      jq
      coreutils
      gnugrep
    ];
    text = ''
      ${resolveFn}
      sel="$(jptv_pick "''${1:-}")" || exit 1
      name="$(printf '%s' "$sel" | cut -f1)"
      url="$(printf '%s' "$sel" | cut -f2)"
      model="''${WHISPER_MODEL:-${whisperModel}}"
      sock="''${XDG_RUNTIME_DIR:-/tmp}/jptv-mpv.sock"
      rm -f "$sock"

      echo "playing: $name  (live JA->EN via whisper-stream, ~3s lag)"
      mpv --input-ipc-server="$sock" --profile=live --force-media-title="$name" "$url" &
      mpvpid=$!
      cleanup() { kill "$mpvpid" 2>/dev/null || true; rm -f "$sock"; }
      trap cleanup EXIT INT TERM

      # wait up to 5s for mpv's ipc socket
      for _ in $(seq 1 50); do [ -S "$sock" ] && break; sleep 0.1; done

      # whisper-stream: continuous sliding-window transcription on the GPU, reading
      # the DESKTOP AUDIO MONITOR (what mpv is playing, so it stays in sync and needs
      # no second stream pull). --step = ms between updates (lower = snappier),
      # --length = context window. it reprints the live guess with CR, so tr splits
      # those into lines; each non-empty one is pushed to mpv's osd. tune with
      # JPTV_STEP / WHISPER_MODEL (tiny = faster, small/medium = better).
      SDL_AUDIODRIVER=pulseaudio PULSE_SOURCE="''${JPTV_SOURCE:-@DEFAULT_MONITOR@}" \
        whisper-stream --translate -l ja -m "$model" \
          --step "''${JPTV_STEP:-2500}" --length 8000 --keep 300 --keep-context -t 8 2>/dev/null \
        | stdbuf -oL tr '\r' '\n' \
        | while IFS= read -r line; do
            kill -0 "$mpvpid" 2>/dev/null || break
            line="$(printf '%s' "$line" | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/^[[:space:]]+//; s/[[:space:]]+$//')"
            case "$line" in "" | "["* | "###"* | whisper_* | main:* | init:*) continue ;; esac
            jq -nc --arg t "$line" '{command:["show-text",$t,4000]}' | socat - "$sock" 2>/dev/null || true
          done
    '';
  };

  # named strm, not stream: imagemagick already ships a `stream` binary.
  strm = pkgs.writeShellApplication {
    name = "strm";
    runtimeInputs = with pkgs; [
      streamlink
      mpv
    ];
    text = ''
      [ "$#" -ge 1 ] || { echo "usage: strm <url> [quality]"; exit 1; }
      exec streamlink --player mpv --player-args "--profile=live" "$1" "''${2:-best}"
    '';
  };
in
{
  home.packages = [
    jptv
    jptvTranslate
    strm
  ];

  # preconfigure hypnotix with the JP list as a "JP IPTV" provider so the GUI opens
  # channel-ready. hypnotix serializes providers as name:::type_id:::url:::user:::pass:::epg
  # (type_id "url" = a remote M3U). the CLI jptv above is the reliable path.
  dconf.settings."org/x/hypnotix".providers = builtins.concatStringsSep ":::" [
    "JP IPTV"
    "url"
    jpList
    ""
    ""
    ""
  ];
}

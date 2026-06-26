#!/usr/bin/env bash
# HOST readout: <wired-name>@<ip>. FIELD label ("HOST:") owned by sketchybarrc.
# the wired name (NAVI/CYBERIA/PROTOCOL7) is cosmetic, the real nix hostname is untouched.
# ip is best-effort and cheap: tailnet 100.x if the tailscale cli is on PATH,
# else the lan addr of the default-route interface. never blocks the bar; any
# probe that fails just drops that half of the value.
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:$PATH"
source "$HOME/.config/sketchybar/colors.sh"

HOST=$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null)
HOST=${HOST:-mac}

# the bar shows the WIRED name, not the real nix hostname. this case mirrors
# home/modules/wired-name.nix exactly (host.sh is bash, it cannot read nix options).
# unknown hosts fall back to the raw hostname, uppercased below like every other.
case "$HOST" in
  otter) WIRED="NAVI" ;;
  coral) WIRED="CYBERIA" ;;
  cuttlefish) WIRED="PROTOCOL7" ;;
  *) WIRED="$HOST" ;;
esac
HOST="$WIRED"

# tailnet first (stable identity across networks), else the default-route lan ip
IP=""
if command -v tailscale >/dev/null 2>&1; then
  IP=$(tailscale ip -4 2>/dev/null | head -1)
fi
if [ -z "$IP" ]; then
  IFACE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
  [ -n "$IFACE" ] && IP=$(ipconfig getifaddr "$IFACE" 2>/dev/null)
fi

if [ -n "$IP" ]; then
  LABEL="${HOST}@${IP}"
else
  LABEL="$HOST"
fi

sketchybar --set "$NAME" \
  label="$(printf '%s' "$LABEL" | tr '[:lower:]' '[:upper:]')" \
  label.color="$ACCENT"

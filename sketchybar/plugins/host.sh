#!/usr/bin/env bash
# HOST readout: <hostname>@<ip>. FIELD label ("HOST:") owned by sketchybarrc.
# ip is best-effort and cheap: tailnet 100.x if the tailscale cli is on PATH,
# else the lan addr of the default-route interface. never blocks the bar; any
# probe that fails just drops that half of the value.
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:$PATH"
source "$HOME/.config/sketchybar/colors.sh"

HOST=$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null)
HOST=${HOST:-mac}

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

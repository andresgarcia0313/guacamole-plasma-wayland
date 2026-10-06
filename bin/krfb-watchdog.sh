#!/bin/bash
# Watches the PipeWire screen stream of krfb on Plasma/Wayland and restarts krfb when it breaks.
# Symptom it fixes: after a monitor change, screen blanking or suspend the stream stops delivering frames
# and every VNC client receives the last old frame (frozen image).
# Restarting krfb is free: the portal permission is pre-authorized for the org.kde.krfb app id.
set -u
UNIT=app-org.kde.krfb@guacamole.service
INTERVAL=2          # seconds between checks
BROKEN_LIMIT=5      # consecutive broken checks before restarting (10 s)
STARTUP_GRACE=45    # seconds allowed for the stream to appear after krfb starts
MIN_GAP=60          # minimum seconds between two automatic restarts

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

# State of the krfb PipeWire node: running (healthy); idle, suspended or missing (broken)
stream_state() {
    pw-dump 2>/dev/null | python3 -c '
import json, sys
try:
    nodes = json.load(sys.stdin)
except ValueError:
    print("unknown"); sys.exit()
for o in nodes:
    p = o.get("info", {}).get("props", {})
    if o.get("type") == "PipeWire:Interface:Node" and "krfb" in json.dumps(p).lower():
        print(o["info"]["state"]); sys.exit()
print("missing")'
}

restart() {
    log "restarting $UNIT: $1"
    last_restart=$SECONDS
    systemctl --user restart "$UNIT"
}

last_restart=-$MIN_GAP
seen_pid=""
since=$SECONDS
alive=0
broken=0
log "watchdog started"
while sleep "$INTERVAL"; do
    pid=$(systemctl --user show "$UNIT" -p MainPID --value)
    if [ "$pid" != "$seen_pid" ]; then
        seen_pid=$pid; alive=0; broken=0; since=$SECONDS
        log "krfb pid=$pid started"
        continue
    fi
    [ "$pid" = "0" ] && continue
    state=$(stream_state)
    if [ "$state" = running ]; then
        [ "$alive" -eq 0 ] && log "stream running"
        alive=1; broken=0
    elif [ "$state" != unknown ]; then
        if [ "$alive" -eq 1 ]; then
            broken=$((broken + 1))
            [ "$broken" -ge "$BROKEN_LIMIT" ] && [ $((SECONDS - last_restart)) -ge "$MIN_GAP" ] \
                && restart "stream is '$state' after it was running"
        elif [ $((SECONDS - since)) -ge "$STARTUP_GRACE" ] && [ $((SECONDS - last_restart)) -ge "$MIN_GAP" ]; then
            restart "stream did not appear in ${STARTUP_GRACE}s (state '$state')"
        fi
    fi
done

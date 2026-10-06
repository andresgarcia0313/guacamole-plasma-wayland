#!/bin/bash
# Creates the private configuration and fills every empty secret with a random value.

# set_config KEY VALUE: writes KEY=VALUE in the config file (replacing an existing line)
set_config() {
    python3 - "$GP_CONFIG" "$1" "$2" <<'PY'
import re, sys
path, key, value = sys.argv[1:]
text = open(path, encoding="utf-8").read()
text, n = re.subn(r"^%s=.*$" % re.escape(key), lambda _: f"{key}={value}", text, flags=re.M)
if not n:
    text += f"\n{key}={value}\n"
open(path, "w", encoding="utf-8").write(text)
PY
}

# fill_secret KEY VALUE: only when the current value is empty
fill_secret() {
    local current
    current=$(grep -E "^$1=" "$GP_CONFIG" | head -n 1 | cut -d= -f2-)
    if [ -z "$current" ] || [ "$current" = '""' ] || [ "$current" = "''" ]; then
        set_config "$1" "$2"
    fi
}

ensure_config() {
    mkdir -p "$GP_CONFIG_DIR"
    chmod 700 "$GP_CONFIG_DIR"
    if [ ! -f "$GP_CONFIG" ]; then
        cp "$GP_ROOT/config.example.env" "$GP_CONFIG"
        log "created $GP_CONFIG"
    fi
    chmod 600 "$GP_CONFIG"
    fill_secret GP_PASS "$(random_string 24)"
    fill_secret GP_TOTP_SECRET "$(base32_secret)"
    fill_secret GP_DB_PASS "$(random_string 32)"
    # VNC authentication only uses the first 8 characters
    fill_secret GP_VNC_PASS "$(random_string 8)"
    fill_secret GP_SSH_PASSPHRASE "$(random_string 28)"
    load_config
}

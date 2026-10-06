#!/bin/bash
# Shared helpers: logging, configuration loading and template rendering.

GP_ROOT=${GP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
GP_CONFIG_DIR=${GP_CONFIG_DIR:-$HOME/.config/guacamole-plasma}
GP_CONFIG=${GP_CONFIG:-$GP_CONFIG_DIR/config.env}
GP_DATA_DIR=${GP_DATA_DIR:-$HOME/.local/share/guacamole-plasma}
QUADLET_DIR=${QUADLET_DIR:-$HOME/.config/containers/systemd}
SYSTEMD_USER_DIR=${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}
export KRFB_UNIT=app-org.kde.krfb@guacamole.service
DRY_RUN=${DRY_RUN:-0}
export GP_ROOT GP_DATA_DIR

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# Runs a command with side effects, or only prints it in dry-run mode
run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

random_string() {
    python3 -c 'import secrets, string, sys
print("".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(int(sys.argv[1]))))' "$1"
}

base32_secret() {
    python3 -c 'import base64, os; print(base64.b32encode(os.urandom(20)).decode())'
}

load_config() {
    [ -f "$GP_CONFIG" ] || die "missing $GP_CONFIG (run install.sh first)"
    set -a
    # shellcheck disable=SC1090
    . "$GP_CONFIG"
    set +a
    : "${GP_DESKTOP:=true}" "${GP_SSH:=true}" "${GP_TOTP:=true}" "${GP_POD:=guac}"
    # systemd unescapes backslashes in Environment=: double them for the proxy regex
    GP_TRUSTED_PROXY_ESC=${GP_TRUSTED_PROXY//\\/\\\\}
    export GP_TRUSTED_PROXY_ESC
}

# render TEMPLATE DEST: replaces only the variables listed below, nothing else
# shellcheck disable=SC2016  # literal ${...} names for envsubst
render() {
    local vars='${GP_USER} ${GP_BIND} ${GP_PORT} ${GP_TRUSTED_PROXY_ESC} ${GP_POD} ${GP_GUAC_VERSION}'
    vars+=' ${GP_POSTGRES_IMAGE} ${GP_TOTP} ${GP_TOTP_ISSUER} ${GP_DATA_DIR} ${GP_ROOT}'
    mkdir -p "$(dirname "$2")"
    envsubst "$vars" <"$1" >"$2"
}

backup_file() {
    [ -e "$1" ] && cp -a -- "$1" "$1.bak-$(date +%s)"
    return 0
}

require() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1 ($2)"
}

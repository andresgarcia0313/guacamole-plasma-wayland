#!/bin/bash
# Installer of guacamole-plasma-wayland: browser access (Apache Guacamole) to a KDE Plasma Wayland desktop.
# Everything runs as the current user (rootless Podman + systemd --user). No sudo is needed.
#
# Usage: ./install.sh [--dry-run] [--no-desktop] [--no-ssh] [--config FILE]
#   --dry-run     render every file but do not pull images, start services or touch the portal
#   --no-desktop  web stack and SSH terminal only (no krfb, no portal permission)
#   --no-ssh      do not create the SSH key nor the terminal connection
set -euo pipefail
GP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
NO_DESKTOP=0 NO_SSH=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) export DRY_RUN=1 ;;
        --no-desktop) NO_DESKTOP=1 ;;
        --no-ssh) NO_SSH=1 ;;
        --config) export GP_CONFIG=$2; shift ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
# shellcheck source=lib/common.sh
. "$GP_ROOT/lib/common.sh"
# shellcheck source=lib/secrets.sh
. "$GP_ROOT/lib/secrets.sh"
# shellcheck source=lib/desktop.sh
. "$GP_ROOT/lib/desktop.sh"
# shellcheck source=lib/stack.sh
. "$GP_ROOT/lib/stack.sh"

[ "$(id -u)" -ne 0 ] || die "run it as your normal user, not as root"
require python3 "install python3"
require systemctl "systemd is required"

log "configuration"
ensure_config
[ "$NO_DESKTOP" = 1 ] && { set_config GP_DESKTOP false; load_config; }
[ "$NO_SSH" = 1 ] && { set_config GP_SSH false; load_config; }

log "checks"
check_stack
[ "$GP_DESKTOP" = true ] && check_desktop

if [ "$GP_SSH" = true ]; then
    log "SSH key for the web terminal"
    setup_ssh_key
fi
if [ "$GP_DESKTOP" = true ]; then
    log "krfb with one-time portal approval"
    setup_krfb
fi

log "Guacamole extension"
GP_APP_NAME=$GP_APP_NAME GP_LOGO=${GP_LOGO:-} python3 "$GP_ROOT/extension/build.py" \
    "$GP_DATA_DIR/extension/guacamole-plasma.jar"

log "containers (pod $GP_POD)"
prepare_stack
start_stack

log "done"
cat <<EOF

  Web interface : http://$GP_BIND:$GP_PORT/   (put a TLS reverse proxy in front, see extras/)
  User          : $GP_USER
  Password      : stored in $GP_CONFIG (GP_PASS)
EOF
if [ "$GP_TOTP" = true ] && [ "$DRY_RUN" != 1 ]; then
    echo "  Two-factor    : scan this code with your authenticator app before the first login"
    python3 "$GP_ROOT/bin/totp-qr.py" "$GP_DATA_DIR/totp-qr.png" || true
fi

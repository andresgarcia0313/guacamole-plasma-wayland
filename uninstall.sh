#!/bin/bash
# Removes guacamole-plasma-wayland. By default keeps the configuration, the database volume and the data.
#
# Usage: ./uninstall.sh [--purge] [--config FILE]
#   --purge   also delete the database volume, data dir, configuration, SSH key entry, portal permission
set -euo pipefail
GP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PURGE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --purge) PURGE=1 ;;
        --config) export GP_CONFIG=$2; shift ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
# shellcheck source=lib/common.sh
. "$GP_ROOT/lib/common.sh"
# shellcheck source=lib/desktop.sh
. "$GP_ROOT/lib/desktop.sh"
load_config

log "stopping the pod $GP_POD"
systemctl --user stop "$GP_POD-web.service" "$GP_POD-guacd.service" "$GP_POD-db.service" "$GP_POD-pod.service" 2>/dev/null || true
for f in "$GP_POD.pod" "$GP_POD-web.container" "$GP_POD-guacd.container" "$GP_POD-db.container"; do
    rm -f -- "${QUADLET_DIR:?}/$f"
done

if [ "$GP_DESKTOP" = true ]; then
    log "stopping krfb and its watchdog"
    systemctl --user disable --now krfb-watchdog.service "$KRFB_UNIT" 2>/dev/null || true
    rm -f -- "${SYSTEMD_USER_DIR:?}/krfb-watchdog.service" "${SYSTEMD_USER_DIR:?}/app-org.kde.krfb@.service"
    rm -rf -- "${SYSTEMD_USER_DIR:?}/app-org.kde.krfb@.service.d"
fi
systemctl --user daemon-reload

if [ "$PURGE" = 1 ]; then
    log "purging data"
    podman volume rm -f "$GP_POD-db-data" >/dev/null 2>&1 || true
    if [ -f "$GP_DATA_DIR/ssh/id_ed25519.pub" ] && [ -f "$HOME/.ssh/authorized_keys" ]; then
        key=$(cut -d' ' -f2 "$GP_DATA_DIR/ssh/id_ed25519.pub")
        backup_file "$HOME/.ssh/authorized_keys"
        grep -vF "$key" "$HOME/.ssh/authorized_keys" >"$HOME/.ssh/authorized_keys.tmp" || true
        mv -- "$HOME/.ssh/authorized_keys.tmp" "$HOME/.ssh/authorized_keys"
        chmod 600 "$HOME/.ssh/authorized_keys"
    fi
    if [ "$GP_DESKTOP" = true ]; then
        for id in remote-desktop screencast; do
            perm_store DeletePermission kde-authorized "$id" org.kde.krfb >/dev/null 2>&1 || true
        done
    fi
    rm -rf -- "${GP_DATA_DIR:?}"
    rm -f -- "${GP_CONFIG:?}"
fi
log "removed (the images stay in podman; krfbrc backups stay in ~/.config)"

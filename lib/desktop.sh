#!/bin/bash
# Desktop side: krfb (VNC of KDE) with a stable app id, portal pre-authorization and a dedicated SSH key.

# perm_store METHOD ARGS...: calls the xdg-desktop-portal permission store of this user session
perm_store() {
    local method=$1
    shift
    gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
        --object-path /org/freedesktop/impl/portal/PermissionStore \
        --method "org.freedesktop.impl.portal.PermissionStore.$method" "$@"
}

check_desktop() {
    require krfb "install the krfb package (KDE Desktop Sharing)"
    require gdbus "install libglib2.0-bin"
    [ "${XDG_SESSION_TYPE:-}" = wayland ] || warn "this session is not Wayland; krfb may need another framebuffer plugin"
    local plasma
    plasma=$(plasmashell --version 2>/dev/null | awk '{print $2}')
    case "$plasma" in
        6.[3-9]*|6.[1-9][0-9]*|[7-9]*) ;;
        *) warn "Plasma $plasma: portal pre-authorization (kde-authorized) needs Plasma 6.3 or newer" ;;
    esac
}

# krfb stores Password-type keys obfuscated (KStringHandler::obscure)
obscure() { python3 -c 'import sys; print("".join(chr(0x1001F - ord(c)) if ord(c) > 0x21 else c for c in sys.argv[1]))' "$1"; }

setup_krfb() {
    local rc=$HOME/.config/krfbrc
    backup_file "$rc"
    umask 077
    cat >"$rc" <<EOF
[FrameBuffer]
preferredFrameBufferPlugin=pw

[Security]
allowDesktopControl=true
allowUnattendedAccess=true
noWallet=true
unattendedPassword=$(obscure "$GP_VNC_PASS")
EOF
    chmod 600 "$rc"
    # One-time approval forever: the KDE portal skips the "Remote control" dialog for this app id
    for id in remote-desktop screencast; do
        run perm_store SetPermission kde-authorized true "$id" org.kde.krfb "['yes']" >/dev/null
    done
    install -D -m 755 "$GP_ROOT/bin/krfb-watchdog.sh" "$GP_DATA_DIR/bin/krfb-watchdog.sh"
    render "$GP_ROOT/systemd/app-org.kde.krfb@.service" "$SYSTEMD_USER_DIR/app-org.kde.krfb@.service"
    render "$GP_ROOT/systemd/krfb-portal.conf" "$SYSTEMD_USER_DIR/app-org.kde.krfb@.service.d/10-portal.conf"
    render "$GP_ROOT/systemd/krfb-watchdog.service" "$SYSTEMD_USER_DIR/krfb-watchdog.service"
    run systemctl --user daemon-reload
    run systemctl --user enable --now "$KRFB_UNIT" krfb-watchdog.service
    warn "krfb listens on port 5900 of every interface: keep it closed in your firewall (see extras/)"
}

setup_ssh_key() {
    local key=$GP_DATA_DIR/ssh/id_ed25519 auth=$HOME/.ssh/authorized_keys
    mkdir -p "$GP_DATA_DIR/ssh" "$HOME/.ssh"
    chmod 700 "$GP_DATA_DIR/ssh" "$HOME/.ssh"
    [ -f "$key" ] || run ssh-keygen -q -t ed25519 -N "$GP_SSH_PASSPHRASE" -C guacamole-plasma -f "$key"
    install -D -m 644 "$GP_ROOT/bin/web-shell-rc.sh" "$GP_DATA_DIR/bin/web-shell-rc.sh"
    [ -f "$key.pub" ] || return 0
    if ! grep -qF "$(cut -d' ' -f2 "$key.pub")" "$auth" 2>/dev/null; then
        backup_file "$auth"
        # Valid only from loopback: the container reaches sshd through the mapped host loopback
        echo "from=\"127.0.0.1,::1\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding $(cat "$key.pub")" >>"$auth"
        chmod 600 "$auth"
    fi
    ss -tln 2>/dev/null | grep -q ':22 ' || warn "no SSH server listening on port 22 (install openssh-server)"
}

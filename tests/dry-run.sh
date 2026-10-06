#!/bin/bash
# Renders a full installation into a temporary HOME (--dry-run) and checks the generated files.
# Touches nothing outside the temporary directory.
# shellcheck disable=SC2016,SC2034,SC2329,SC2015,SC1090
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "${TMP:?}"' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

export HOME=$TMP
mkdir -p "$TMP/.config/guacamole-plasma"
cp "$ROOT/config.example.env" "$TMP/.config/guacamole-plasma/config.env"
sed -i 's/^GP_TRUSTED_PROXY=.*/GP_TRUSTED_PROXY='"'"'10\\.0\\.0\\.1'"'"'/' "$TMP/.config/guacamole-plasma/config.env"
DRY_RUN=1 bash "$ROOT/install.sh" --dry-run >"$TMP/out.log" 2>&1 || { cat "$TMP/out.log"; echo "FAIL installer"; exit 1; }

CFG=$TMP/.config/guacamole-plasma/config.env
Q=$TMP/.config/containers/systemd
S=$TMP/.config/systemd/user
check "config is private"            '[ "$(stat -c %a "$CFG")" = 600 ]'
check "password generated"           'grep -qE "^GP_PASS=[A-Za-z0-9]{24}$" "$CFG"'
check "TOTP secret generated"        'grep -qE "^GP_TOTP_SECRET=[A-Z2-7]{32}$" "$CFG"'
check "VNC password has 8 chars"     'grep -qE "^GP_VNC_PASS=[A-Za-z0-9]{8}$" "$CFG"'
check "quadlet files rendered"       '[ -f "$Q/guac.pod" ] && [ -f "$Q/guac-web.container" ] && [ -f "$Q/guac-db.container" ]'
check "no placeholders left"         '! grep -rl "\${GP_" "$Q" "$S"'
check "pod publishes on 127.0.0.1"   'grep -q "PublishPort=127.0.0.1:8087:8080" "$Q/guac.pod"'
check "pod maps host loopback"       'grep -q "map-host-loopback" "$Q/guac.pod"'
check "proxy regex escaped"          'grep -qF "INTERNAL_PROXIES=10\\\\.0\\\\.0\\\\.1" "$Q/guac-web.container"'
check "issuer with spaces quoted"    'grep -q "^Environment=\"TOTP_ISSUER=Guacamole Plasma\"" "$Q/guac-web.container"'
check "web uses POSTGRESQL_ only"    '! grep -q "POSTGRES_" "$TMP/.local/share/guacamole-plasma/db/web-db.env"'
check "krfb unit with app id"        '[ -f "$S/app-org.kde.krfb@.service" ]'
check "portal drop-in"               'grep -q kde-authorized "$S/app-org.kde.krfb@.service.d/10-portal.conf"'
check "krfbrc password obscured"     '! grep -q "unattendedPassword=$(grep ^GP_VNC_PASS= "$CFG" | cut -d= -f2)$" "$TMP/.config/krfbrc"'
check "extension built"              '[ -s "$TMP/.local/share/guacamole-plasma/extension/guacamole-plasma.jar" ]'
check "app name in translations"     'unzip -p "$TMP/.local/share/guacamole-plasma/extension/guacamole-plasma.jar" translations/es.json | grep -q "Remote Desktop"'

echo
[ "$fails" -eq 0 ] && echo "dry-run: all passed" || { echo "dry-run: $fails failed"; tail -20 "$TMP/out.log"; }
exit "$fails"

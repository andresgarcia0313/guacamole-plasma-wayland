#!/bin/bash
# Real end-to-end test of the web stack in a parallel, throw-away pod (no desktop, no SSH): installs it,
# checks the login with and without TOTP and the removal of guacadmin, then purges everything.
# Needs rootless Podman and systemd --user. Uses port 18087 and the pod name "gptest".
# shellcheck disable=SC2016,SC2034,SC2329,SC2015,SC1090
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
export GP_CONFIG=$TMP/config.env GP_DATA_DIR=$TMP/data
cp "$ROOT/config.example.env" "$GP_CONFIG"
sed -i -e 's/^GP_POD=.*/GP_POD=gptest/' -e 's/^GP_PORT=.*/GP_PORT=18087/' "$GP_CONFIG"
cleanup() { bash "$ROOT/uninstall.sh" --purge --config "$GP_CONFIG" >/dev/null 2>&1; rm -rf -- "${TMP:?}"; }
trap cleanup EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

bash "$ROOT/install.sh" --no-desktop --no-ssh --config "$GP_CONFIG" >"$TMP/install.log" 2>&1 \
    || { tail -30 "$TMP/install.log"; echo "FAIL installer"; exit 1; }
# shellcheck disable=SC1090
set -a; . "$GP_CONFIG"; set +a
URL=http://127.0.0.1:18087/api/tokens
code() { python3 -c 'import base64,hmac,hashlib,struct,sys,time
s=sys.argv[1]; k=base64.b32decode(s+"="*(-len(s)%8)); h=hmac.new(k,struct.pack(">Q",int(time.time()//30)),hashlib.sha1).digest()
o=h[-1]&15; print("%06d"%((struct.unpack(">I",h[o:o+4])[0]&0x7fffffff)%1000000))' "$1"; }
login() { curl -s -X POST "$URL" -d "username=$1" --data-urlencode "password=$2" ${3:+--data-urlencode "guac-totp=$3"}; }

check "web answers"                     'curl -sf -o /dev/null http://127.0.0.1:18087/'
# Count instead of "grep -q": with pipefail an early grep exit makes the pipeline fail (false negative)
loaded() { [ "$(podman logs gptest-web 2>&1 | grep -c "($1) loaded")" -gt 0 ]; }
check "extension loaded"                'loaded gplasma'
check "TOTP and PostgreSQL loaded"      'loaded totp && loaded postgresql'
check "password alone asks for TOTP"    'login "$GP_USER" "$GP_PASS" | grep -q "guac-totp"'
check "password + code gives a token"   'login "$GP_USER" "$GP_PASS" "$(code "$GP_TOTP_SECRET")" | grep -q authToken'
check "guacadmin was removed"           '! login guacadmin guacadmin | grep -q authToken'
check "database not published"          '! ss -tln | grep -q ":5432 "'

echo
[ "$fails" -eq 0 ] && echo "stack: all passed" || echo "stack: $fails failed"
exit "$fails"

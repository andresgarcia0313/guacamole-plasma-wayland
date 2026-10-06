#!/bin/bash
# Static checks: syntax, shellcheck, Python, JavaScript, JSON, typography of the docs and secret leaks.
# shellcheck disable=SC2329,SC2015
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fails=0
check() { if "$@"; then echo "ok   $*"; else echo "FAIL $*"; fails=$((fails + 1)); fi; }

mapfile -t shells < <(git ls-files '*.sh')
for f in "${shells[@]}"; do check bash -n "$f"; done
if command -v shellcheck >/dev/null; then
    check shellcheck -x -e SC1091 "${shells[@]}"
else
    echo "skip shellcheck (not installed)"
fi
for f in $(git ls-files '*.py'); do check python3 -m py_compile "$f"; done
if command -v node >/dev/null; then
    for f in $(git ls-files '*.js'); do check node --check "$f"; done
fi
for f in $(git ls-files '*.json'); do check python3 -m json.tool "$f" >/dev/null; done

# Documentation: plain hyphen only (no en dash or em dash)
no_dashes() { ! grep -nP '[\x{2013}\x{2014}]' "$@"; }
mapfile -t docs < <(git ls-files '*.md')
[ ${#docs[@]} -eq 0 ] || check no_dashes "${docs[@]}"

# Secret leaks: private keys, tokens and filled secrets in the example configuration
no_secrets() {
    ! git grep -nE 'BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' -- . ':!tests/static.sh' &&
    ! grep -nE '^GP_(PASS|TOTP_SECRET|DB_PASS|VNC_PASS|SSH_PASSPHRASE)=.+' config.example.env
}
check no_secrets

echo
[ "$fails" -eq 0 ] && echo "static checks: all passed" || echo "static checks: $fails failed"
exit "$fails"

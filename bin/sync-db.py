#!/usr/bin/env python3
"""Writes the user, its connections and its TOTP secret into the Guacamole PostgreSQL database.

Idempotent. Always deletes the default guacadmin account created by the schema.
Usage: sync-db.py                     sync the main user from config.env
       sync-db.py --temp USER PASS    create a temporary test user (prints its TOTP secret)
       sync-db.py --delete USER       delete a user
"""
import base64
import getpass
import os
import shlex
import subprocess
import sys

from db_sql import GRANTS, connection_sql, lit, user_sql

CONFIG = os.environ.get("GP_CONFIG", os.path.expanduser("~/.config/guacamole-plasma/config.env"))
DATA = os.environ.get("GP_DATA_DIR", os.path.expanduser("~/.local/share/guacamole-plasma"))


def read_config():
    values = {}
    for line in open(CONFIG, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, raw = line.split("=", 1)
            parsed = shlex.split(raw, comments=True)
            values[key.strip()] = parsed[0] if parsed else ""
    return values


def connections(cfg):
    found = []
    if cfg.get("GP_DESKTOP", "true") == "true":
        found.append(("Desktop (VNC)", "vnc", {
            "hostname": "host.containers.internal", "port": "5900", "password": cfg["GP_VNC_PASS"],
            # krfb on Wayland does not paint the pointer into the image: the cursor must be local
            "clipboard-encoding": "UTF-8", "cursor": "local"}))
    key = os.path.join(DATA, "ssh", "id_ed25519")
    if cfg.get("GP_SSH", "true") == "true" and os.path.exists(key):
        found.append(("Terminal (SSH)", "ssh", {
            "hostname": "host.containers.internal", "port": "22", "username": getpass.getuser(),
            "private-key": open(key, encoding="utf-8").read(), "passphrase": cfg["GP_SSH_PASSPHRASE"],
            "command": f"bash --rcfile {os.path.join(DATA, 'bin', 'web-shell-rc.sh')} -i",
            "color-scheme": "white-black", "font-size": "13", "scrollback": "3000"}))
    return found


def execute(cfg, sql):
    cmd = ["podman", "exec", "-i", f"{cfg.get('GP_POD', 'guac')}-db", "psql", "-q", "-v", "ON_ERROR_STOP=1",
           "-U", "guacamole", "-d", "guacamole_db"]
    result = subprocess.run(cmd, input=sql, text=True, capture_output=True)
    if result.returncode:
        sys.exit("psql failed: " + result.stderr.strip())


def main():
    cfg = read_config()
    totp = cfg.get("GP_TOTP", "true") == "true"
    if len(sys.argv) == 3 and sys.argv[1] == "--delete":
        execute(cfg, f"DELETE FROM guacamole_entity WHERE name = {lit(sys.argv[2])} AND type = 'USER';")
        return print("deleted", sys.argv[2])
    if len(sys.argv) == 4 and sys.argv[1] == "--temp":
        secret = base64.b32encode(os.urandom(20)).decode() if totp else ""
        users = [(sys.argv[2], sys.argv[3], secret)]
        print("temporary TOTP secret:", secret or "(TOTP disabled)")
    else:
        users = [(cfg["GP_USER"], cfg["GP_PASS"], cfg["GP_TOTP_SECRET"] if totp else "")]
    sql = ["BEGIN;", "DELETE FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER';"]
    sql += [connection_sql(*c) for c in connections(cfg)]
    sql += [user_sql(*u) for u in users]
    sql += [GRANTS, "COMMIT;"]
    execute(cfg, "\n".join(sql))
    print("synchronized:", ", ".join(u[0] for u in users))


if __name__ == "__main__":
    main()

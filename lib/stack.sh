#!/bin/bash
# Web side: rootless Podman pod (guacd + Guacamole + PostgreSQL) managed by Quadlet.

check_stack() {
    require podman "install podman 4.4 or newer (Quadlet)"
    require pasta "install the passt package"
    require envsubst "install gettext-base"
    local v
    v=$(podman version --format '{{.Client.Version}}' 2>/dev/null || echo 0)
    case "$v" in 4.[4-9]*|4.[1-9][0-9]*|[5-9].*) ;; *) die "podman $v is too old: Quadlet needs 4.4+" ;; esac
    [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = true ] || warn "podman is not rootless"
}

prepare_stack() {
    local db=$GP_DATA_DIR/db
    mkdir -p "$db"
    chmod 700 "$db"
    for img in "docker.io/guacamole/guacd:$GP_GUAC_VERSION" "docker.io/guacamole/guacamole:$GP_GUAC_VERSION" \
        "$GP_POSTGRES_IMAGE"; do
        run podman pull -q "$img" >/dev/null
    done
    if [ "$DRY_RUN" != 1 ]; then
        podman run --rm --entrypoint /opt/guacamole/bin/initdb.sh \
            "docker.io/guacamole/guacamole:$GP_GUAC_VERSION" --postgresql >"$db/001-schema.sql"
        grep -q 'CREATE TABLE' "$db/001-schema.sql" || die "could not generate the database schema"
    fi
    chmod 644 "$db/001-schema.sql" 2>/dev/null || true
    (
        umask 077
        printf 'POSTGRES_DB=guacamole_db\nPOSTGRES_USER=guacamole\nPOSTGRES_PASSWORD=%s\n' "$GP_DB_PASS" >"$db/db.env"
        printf 'POSTGRESQL_PASSWORD=%s\n' "$GP_DB_PASS" >"$db/web-db.env"
    )
    render "$GP_ROOT/quadlet/pod.pod" "$QUADLET_DIR/$GP_POD.pod"
    for part in guacd db web; do
        render "$GP_ROOT/quadlet/$part.container" "$QUADLET_DIR/$GP_POD-$part.container"
    done
}

wait_for() { # description, seconds, command...
    local what=$1 limit=$2 start=$SECONDS
    shift 2
    until "$@" >/dev/null 2>&1; do
        [ $((SECONDS - start)) -ge "$limit" ] && die "timeout waiting for $what"
        sleep 2
    done
}

start_stack() {
    [ "$DRY_RUN" = 1 ] && { log "[dry-run] would start $GP_POD"; return 0; }
    systemctl --user daemon-reload
    systemctl --user start "$GP_POD-db.service" "$GP_POD-guacd.service"
    wait_for "database" 120 podman exec "$GP_POD-db" psql -U guacamole -d guacamole_db -tAc \
        'select 1 from guacamole_entity limit 1'
    python3 "$GP_ROOT/bin/sync-db.py"
    systemctl --user restart "$GP_POD-web.service"
    local host=$GP_BIND
    [ "$host" = 0.0.0.0 ] && host=127.0.0.1
    wait_for "web interface on $host:$GP_PORT" 180 curl -sf -o /dev/null "http://$host:$GP_PORT/"
    loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q yes \
        || warn "lingering is off: the services stop when you log out (loginctl enable-linger $USER)"
}

"""SQL builders for the Guacamole PostgreSQL schema (used by sync-db.py)."""
import hashlib
import os


def lit(value):
    """SQL literal with dollar quoting (private keys contain newlines)."""
    if "$v$" in value:
        raise ValueError("value contains the quote marker")
    return f"$v${value}$v$"


def user_sql(name, password, totp_secret):
    salt = os.urandom(32)
    digest = hashlib.sha256((password + salt.hex().upper()).encode()).hexdigest()
    sql = f"""
DELETE FROM guacamole_entity WHERE name = {lit(name)} AND type = 'USER';
INSERT INTO guacamole_entity (name, type) VALUES ({lit(name)}, 'USER');
INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date)
  SELECT entity_id, decode('{digest}', 'hex'), decode('{salt.hex()}', 'hex'), now()
  FROM guacamole_entity WHERE name = {lit(name)} AND type = 'USER';"""
    if totp_secret:
        sql += f"""
INSERT INTO guacamole_user_attribute (user_id, attribute_name, attribute_value)
  SELECT u.user_id, a.n, a.v FROM guacamole_user u JOIN guacamole_entity e USING (entity_id),
  (VALUES ('guac-totp-key-secret', {lit(totp_secret)}), ('guac-totp-key-confirmed', 'true')) AS a(n, v)
  WHERE e.name = {lit(name)} AND e.type = 'USER';"""
    return sql


def connection_sql(name, protocol, params):
    rows = ",\n    ".join(f"({lit(k)}, {lit(v)})" for k, v in params.items())
    return f"""
DELETE FROM guacamole_connection WHERE connection_name = {lit(name)} AND parent_id IS NULL;
INSERT INTO guacamole_connection (connection_name, protocol) VALUES ({lit(name)}, {lit(protocol)});
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
  SELECT c.connection_id, p.k, p.v FROM guacamole_connection c, (VALUES {rows}) AS p(k, v)
  WHERE c.connection_name = {lit(name)} AND c.parent_id IS NULL;"""


# Recreating connections drops their permissions in cascade: grant READ to every user again
GRANTS = """
INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
  SELECT e.entity_id, c.connection_id, 'READ' FROM guacamole_entity e, guacamole_connection c
  WHERE e.type = 'USER' ON CONFLICT DO NOTHING;"""

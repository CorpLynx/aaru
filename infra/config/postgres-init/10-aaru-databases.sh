#!/usr/bin/env bash
# Aaru PostgreSQL databases and roles
# One database and one least-privilege role per service (spec §2, §7):
#   litellm   — LiteLLM keys, usage, budgets
#   openwebui — Open WebUI accounts, chats, files
# Neither role is a superuser or can create databases or roles, and neither
# can connect to the other's database.
#
# Runs automatically from /docker-entrypoint-initdb.d on an empty data volume.
# Safe to re-run on an existing cluster (also resets the role passwords to the
# current secrets):
#   podman exec postgres /docker-entrypoint-initdb.d/10-aaru-databases.sh
#
# Role passwords are read from Podman secrets mounted at /run/secrets/ inside
# psql, so they never appear in process arguments or the environment.

set -euo pipefail

for secret in litellm-db-password openwebui-db-password; do
    [ -s "/run/secrets/${secret}" ] || { echo "ERROR: /run/secrets/${secret} missing or empty"; exit 1; }
done

psql -v ON_ERROR_STOP=1 --no-psqlrc \
    --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB:-${POSTGRES_USER}}" <<'SQL'
\set litellm_pw `cat /run/secrets/litellm-db-password`
\set openwebui_pw `cat /run/secrets/openwebui-db-password`

SELECT 'CREATE ROLE litellm LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'litellm') \gexec
SELECT 'CREATE ROLE openwebui LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'openwebui') \gexec

SELECT format('ALTER ROLE litellm PASSWORD %L', :'litellm_pw') \gexec
SELECT format('ALTER ROLE openwebui PASSWORD %L', :'openwebui_pw') \gexec

SELECT 'CREATE DATABASE litellm OWNER litellm'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'litellm') \gexec
SELECT 'CREATE DATABASE openwebui OWNER openwebui'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'openwebui') \gexec

-- Only the owning role (and the superuser) may connect to each database.
REVOKE ALL ON DATABASE litellm FROM PUBLIC;
REVOKE ALL ON DATABASE openwebui FROM PUBLIC;
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SQL

echo "aaru: litellm and openwebui databases and roles are in place"

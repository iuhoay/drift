-- Runs once on first init of an empty drift_pgdata volume.
-- POSTGRES_USER already created the superuser role `root` (used by the
-- production primary DB). The cache/queue/cable connections in
-- config/database.yml default their username to `drift`, so that role
-- must exist too. Superuser + trust auth keeps local setup friction-free;
-- db:prepare (run by bin/docker-entrypoint) creates the four databases.
CREATE ROLE drift WITH LOGIN SUPERUSER;

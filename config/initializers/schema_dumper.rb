# Keep the single-DB development/test setup from leaking into the primary schema.
#
# In production each of these subsystems owns a dedicated database with its own
# schema file (see config/database.yml and db/*_schema.rb):
#   - Solid Queue / Cache / Cable -> queue/cache/cable databases
#   - Rails Pulse                  -> rails_pulse database
#
# In development/test drift runs on a single database, so those tables are loaded
# into the primary DB (lib/tasks/solid_schemas.rake plus the rails_pulse db:prepare
# hook). They must never be captured in the app's primary db/schema.rb, which the
# production primary database does not contain.
ActiveRecord::SchemaDumper.ignore_tables |= [
  /\Asolid_(queue|cache|cable)_/,
  /\Arails_pulse_/
]

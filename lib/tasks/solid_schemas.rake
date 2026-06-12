namespace :db do
  desc "Load Solid Queue / Cache / Cable and Rails Pulse schemas into the primary database (dev/test single-DB setup)"
  task load_solid_schemas: :environment do
    if Rails.env.production?
      puts "Skipping solid schema load in production (separate connections in database.yml)."
      next
    end

    # Rails Pulse ships a self-invoking schema lambda that loads into
    # RailsPulse::ApplicationRecord.connection — the primary DB here, since
    # config.connects_to is only set in production (config/initializers/rails_pulse.rb).
    [ "db/queue_schema.rb", "db/cache_schema.rb", "db/cable_schema.rb", "db/rails_pulse_schema.rb" ].each do |path|
      next unless File.exist?(Rails.root.join(path))

      ActiveRecord::Schema.verbose = false
      load Rails.root.join(path)
    end
  end
end

# Ensure Solid Queue/Cache/Cable tables exist after every migrate / db:setup in dev/test.
Rake::Task["db:migrate"].enhance do
  Rake::Task["db:load_solid_schemas"].invoke unless Rails.env.production?
end

Rake::Task["db:setup"].enhance do
  Rake::Task["db:load_solid_schemas"].invoke unless Rails.env.production?
end

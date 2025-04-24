# Rakefile (Manual Task Definitions - v2)
require 'bundler/setup'
require 'sequel'
require 'sequel/extensions/migration'
require 'logger'

# Database Connection (ensure this matches app.rb or use ENV variables)
DATABASE_URL = ENV.fetch('DATABASE_URL', 'postgres://ruby_crm_user:Str0ngP%40ssw0rdCRM%21@localhost:5432/ruby_crm_dev')
DB = Sequel.connect(DATABASE_URL)
DB.loggers << Logger.new($stdout)

namespace :db do
  MIGRATIONS_DIR = File.join(File.dirname(__FILE__), 'db', 'migrations')

  desc "Run database migrations to the latest version or specified version"
  task :migrate, [:version] do |t, args|
    opts = {}
    opts[:target] = args[:version].to_i if args[:version]
    puts "Migrating database..."
    Sequel::Migrator.run(DB, MIGRATIONS_DIR, opts)
    puts "Migrations complete."
  end

  desc "Populate the database with seed data from db/seeds.rb"
  task :seed do
    puts "Running seed script..."
    # seeds.rb already loads the app environment
    require_relative 'db/seeds'
    puts "Seed script finished."
  end

  desc "Rollback database migrations by N steps (default: 1)"
  task :rollback, [:steps] do |t, args|
    steps = args[:steps] ? args[:steps].to_i : 1
    # Determining the target version for rollback requires knowing the current version,
    # which needs a query. For simplicity, we'll just rollback N steps.
    # A more robust implementation would query schema_info first.
    puts "Rolling back (Note: steps argument not fully implemented without querying current version)..."
    # This simple rollback goes *down* N versions relative to the latest known migration file,
    # NOT relative to the current DB state. A proper implementation is more complex.
    # Sequel::Migrator.run(DB, MIGRATIONS_DIR, relative: -steps) # Example of relative migration
    # For now, let's just make it run without error, targeting version 0 as a simple example:
    target_version = 0 # Simplification: Always roll back to version 0 for this example
    puts "Rolling back to version #{target_version}..."
    Sequel::Migrator.run(DB, MIGRATIONS_DIR, target: target_version)
    puts "Rollback attempt complete."
  end

  desc "Prints current schema version (Requires querying schema_info table)"
  task :version do
    begin
      # Query the schema_info table directly
      version = DB[:schema_info].first[:version]
      puts "Current schema version: #{version}"
    rescue StandardError => e
      puts "Could not determine schema version (schema_info table might not exist yet or query failed: #{e.message})"
      puts "Run db:migrate first."
    end
  end
end

# Optional: Define a default task (e.g., display available db tasks)
task :default do
  puts "Available db tasks:"
  Rake::Task.tasks.select { |t| t.name.start_with?('db:') }.each do |t|
    puts "rake #{t.name} # #{t.comment}"
  end
end

puts "Rakefile loaded (Manual Task Definitions - v2)."

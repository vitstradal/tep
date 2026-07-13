# Testovací a lokální prostředí běží na sqlite3, ale db/schema.rb je dumpnuté
# z PostgreSQL a obsahuje sloupce typu timestamptz, které sqlite3 adaptér
# nezná. Nauč ho je brát jako datetime, aby šlo schéma do sqlite nahrát
# (rails db:test:load_schema, rails test). Na postgresu se tento kód nespustí.
ActiveSupport.on_load(:active_record_sqlite3adapter) do
  ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.class_eval do
    def timestamptz(*names, **options)
      names.each { |name| column(name, :datetime, **options) }
    end
  end
end

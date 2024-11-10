# lib/tasks/convert_booleans.rake
namespace :db do
  desc "Convert boolean columns from 't'/'f' to 1/0 in SQLite"
  task convert_booleans: :environment do
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.columns(table).each do |column|
        if column.sql_type == "boolean"
          puts "Converting boolean column #{table}.#{column.name}"
          ActiveRecord::Base.connection.execute <<-SQL
            UPDATE #{table}
            SET #{column.name} = CASE #{column.name}
              WHEN 't' THEN 1
              WHEN 'f' THEN 0
              ELSE #{column.name}
            END
          SQL
        end
      end
    end
  end
end

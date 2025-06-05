require 'csv'
TOWN_LOCATIV = CSV.read(
  Rails.root.join("config/initializers/town_locativ.csv"),
  headers: true,
  header_converters: :symbol,
  col_sep: ';',
) \
.map(&:to_h) \
.map { |line| [ line[:nominativ], line[:locativ] ]}
.to_h

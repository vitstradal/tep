##
# Dummy modul, jen aby se tabuky tříd Sosna::*, jmenovaly `sosna_`.
module Sosna
  ##
  # *Returns* 'sosna_'
  def self.table_name_prefix
    'sosna_'
  end
end

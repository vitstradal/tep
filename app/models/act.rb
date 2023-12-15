##
# Dummy modul, jen aby se tabuky tříd Act::*, jmenovaly `act_`.
module Act
  ##
  # *Returns* 'act_'
  def self.table_name_prefix
    'act_'
  end
end

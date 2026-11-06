class TshirtSizesLettersAll < ActiveRecord::Migration[7.2]
  SIZES = 'XS,S,M,L,XL,XXL,3XL'.freeze

  def up
    change_column_default :act_events, :spec_tshirt_detail, SIZES
    execute "UPDATE act_events SET spec_tshirt_detail = #{connection.quote(SIZES)} WHERE spec_tshirt_detail <> #{connection.quote(SIZES)} OR spec_tshirt_detail IS NULL"
  end

  def down; end
end

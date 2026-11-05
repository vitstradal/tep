class TshirtSizesLettersOnly < ActiveRecord::Migration[7.2]
  OLD = "116,128,140,152,164,XS,S,M,L,XL,XXL"
  NEW = "XS,S,M,L,XL,XXL,3XL"

  def up
    change_column_default :act_events, :spec_tshirt_detail, NEW
    execute "UPDATE act_events SET spec_tshirt_detail = #{quote(NEW)} WHERE spec_tshirt_detail = #{quote(OLD)}"
  end

  def down
    change_column_default :act_events, :spec_tshirt_detail, OLD
    execute "UPDATE act_events SET spec_tshirt_detail = #{quote(OLD)} WHERE spec_tshirt_detail = #{quote(NEW)}"
  end

  private

  def quote(s)
    connection.quote(s)
  end
end

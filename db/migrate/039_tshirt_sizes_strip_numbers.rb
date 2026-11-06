class TshirtSizesStripNumbers < ActiveRecord::Migration[7.2]
  LETTERS = 'XS,S,M,L,XL,XXL,3XL'.freeze

  def up
    select_rows('SELECT id, spec_tshirt_detail FROM act_events').each do |id, detail|
      sizes = detail.to_s.split(',').map(&:strip).reject { |s| s.empty? || s.match?(/\A\d+\z/) }
      new = sizes.empty? ? LETTERS : sizes.join(',')
      next if new == detail
      execute "UPDATE act_events SET spec_tshirt_detail = #{connection.quote(new)} WHERE id = #{id.to_i}"
    end
  end

  def down; end
end

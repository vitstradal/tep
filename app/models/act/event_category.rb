require 'pp'

class Act::EventCategory < ActiveRecord::Base
  self.primary_key = :code

  has_many :events
  has_many :event_participants, through: :events

  validates :code, :presence => true, uniqueness: { case_sensitive: false,  message: "Kódy jednotlivých typů akcí musí být unikátní!" }
  validates :name, :presence => true
  validates :visible, :presence => true

  def self.category_unique(new_code, old_code)
    records_array = Act::EventCategory.where(code: new_code)

    if records_array.length() == 0 || new_code == old_code
      true
    else
      false
    end
  end

  VISIBLE_STATUSES = ['ev', 'user', 'org']
  VISIBLE_STATUSES_TXT = { 'ev' => 'Každý', 'user' => 'Uživatel', 'org' => 'org' }

  def self.category_visible?(visibility_status, current_user)
    if(visibility_status == 'ev' || current_user && (current_user.org? || (current_user.user? && visibility_status=='user')))
      true
    else
      false
    end
  end

  def multi_day_txt()
    multi_day ? "Ano" : "Ne"
  end

  def restrictions_electible_txt()
    restrictions_electible ? "Ano" : "Ne"
  end

  def mass_spec_electible_txt()
    mass_spec_electible ? "Ano" : "Ne"
  end


  def self.multi_day?(code)
    category = Act::EventCategory.find_by(code: code)
    if category.nil?
      return false
    else
      return category.multi_day
    end
  end

  def self.all_multi_day()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE multi_day = 't'").map { |ec| ec["code"] }
  end

  def self.all_for_ev()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE visible = 'ev'").map { |ec| ec["code"] }
  end

  def self.all_for_user()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE visible = 'user'").map { |ec| ec["code"] }
  end

  def self.all_for_org()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE visible = 'org'").map { |ec| ec["code"] }
  end

  def self.all_restrictible()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE restrictions_electible = 't'").map { |ec| ec["code"] }
  end

  def self.all_mass_spec_electible()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE mass_spec_electible = 't'").map { |ec| ec["code"] }
  end

  def self.all_full_act()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE activation_needed_default = 'full'").map { |ec| ec["code"] }
  end

  def visible_txt()
    VISIBLE_STATUSES_TXT[visible]
  end
end

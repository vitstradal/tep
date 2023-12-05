  ##
  #   Typ akce je škatulka zjednodušující práci s akcemi samotnými. Každá akce náleží právě jednomu typu akce.
  #
  # *Columns*
  #    t.string   "code",                      limit: 2
  #    t.index    "code",                      unique: true
  #    t.string   "name"
  #    t.integer  "idx",                       :default => 0
  #    t.boolean  "multi_day",                 :default => true
  #    t.text     "description",               :default => ""
  #    t.string   "visible",                   :default => "ev"
  #    t.boolean  "restrictions_electible",    :default => true
  #    t.boolean  "mass_spec_electible",       :default => true
  #    t.string   "activation_needed_default", :default => "full"

class Act::EventCategory < ActiveRecord::Base
  self.primary_key = :code

  has_many :events
  has_many :event_participants, through: :events

  validates :code, :presence => true, uniqueness: { case_sensitive: false,  message: "Kódy jednotlivých typů akcí musí být unikátní!" }
  validates :name, :presence => true
  validates :visible, :presence => true

  ##
  # *Returns* Když změním kód, bude stále unikátní?
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

  ##
  # *Returns* Vidí daný uživatel daný typ akce?
  def self.category_visible?(visibility_status, current_user)
    if(visibility_status == 'ev' || current_user && (current_user.org? || (current_user.user? && visibility_status=='user')))
      true
    else
      false
    end
  end

  ##
  # *Returns* Je vícedenní?
  def multi_day_txt()
    multi_day ? "Ano" : "Ne"
  end

  ##
  # *Returns* Je uživateli tvořícímu akce tohoto typu umožněno znemožnit některým účastníkům se jí zúčastnit.
  def restrictions_electible_txt()
    restrictions_electible ? "Ano" : "Ne"
  end

  ##
  # *Returns* Je uživateli tvořícímu akce tohoto typu umožněno umožnit účastníkům specifikovat, jestli chtějí na mši?
  def mass_spec_electible_txt()
    mass_spec_electible ? "Ano" : "Ne"
  end

  ##
  # *Returns* Je akce definovaná tímto kódem vícedenní, pokud vůbec existuje?
  def self.multi_day?(code)
    category = Act::EventCategory.find_by(code: code)
    if category.nil?
      return false
    else
      return category.multi_day
    end
  end

  ##
  # *Returns* Všechny vícedenní typy akcí
  def self.all_multi_day()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE multi_day = 't'").map { |ec| ec["code"] }
  end

  ##
  # *Returns* Všechny typy akcí, které jsou viditelné pro všechny
  def self.all_for_ev()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE visible = 'ev'").map { |ec| ec["code"] }
  end

  ##
  # *Returns* Všechny typy akcí, které jsou viditelné pouze pro přihlášené uživatele
  def self.all_for_user()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE visible = 'user'").map { |ec| ec["code"] }
  end

  ##
  # *Returns* Všechny typy akcí, které jsou viditelné pouze pro přihlášené orgy
  def self.all_for_org()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE visible = 'org'").map { |ec| ec["code"] }
  end

  ##
  # *Returns* Všechny typy akcí, které umožňují orgovi tvořícímu akci příslušící danému typu znemožnit některým účastníkům se jí zúčastnit.
  def self.all_restrictible()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE restrictions_electible = 't'").map { |ec| ec["code"] }
  end

  ##
  # *Returns* Všechny typy akcí, pro které platí, že je uživateli tvořícímu akce tohoto typu umožněno umožnit účastníkům specifikovat, jestli chtějí na mši
  def self.all_mass_spec_electible()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE mass_spec_electible = 't'").map { |ec| ec["code"] }
  end

  ##
  # *Returns* Všechny typy akcí, které mají default aktivace účtu jako "full"
  def self.all_full_act()
    return ActiveRecord::Base.connection.execute("SELECT code FROM act_event_categories WHERE activation_needed_default = 'full'").map { |ec| ec["code"] }
  end
  
  def visible_txt()
    VISIBLE_STATUSES_TXT[visible]
  end
end

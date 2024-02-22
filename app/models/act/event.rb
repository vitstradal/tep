  ##
  # Akce, na kterou se mohou (pokud to organizátoři povolí) přihlašovat účastníci
  #
  #
  # *Columns*
  #    t.integer  "event_id",                            index: true
  #    t.date     "event_start"
  #    t.date     "event_end"
  #    t.string   "title"
  #    t.text     "body"
  #    t.string   "event_category",                     :default => "ot"
  #    t.string   "event_info_url",                     :default => ""
  #    t.string   "event_photos_url",                   :default => ""
  #    t.string   "visible",                            :default => "ev"
  #    t.boolean  "spec_place",                         :default => false
  #    t.string   "spec_place_detail",                  :default => ""
  #    t.boolean  "spec_participant",                   :default => false
  #    t.boolean  "spec_mass",                          :default => false
  #    t.string   "bonz_org",                           :default => ""
  #    t.boolean  "bonz_parent",                        :default => false
  #    t.boolean  "limit_num_participants",             :default => false
  #    t.integer  "max_participants",                   :default => 0
  #    t.boolean  "enable_only_specific_participants",  :default => false
  #    t.boolean  "enable_only_specific_substitutes",   :default => false
  #    t.boolean  "enable_only_specific_organisers",    :default => false
  #    t.boolean  "uninvited_participants_dont_see",    :default => false
  #    t.boolean  "uninvited_organisers_dont_see",      :default => false
  #    t.string   "activation_needed",                  :default => "full"
  #    t.boolean  "limit_maybe",                        :default => false
  #    t.date     "maybe_deadline"

  ##
  # Zkontroluje, že akce končí až po svém začátku. Pokud je jednodenní, tak navíc zkopíruje hodnotu položky "konec akce" do položky "začátek akce"
class Act::StartBeforeEndValidator < ActiveModel::Validator
  def validate(record)
    failed = false
    if(record.event_start.nil?)
      record.errors[:event_start] << "Akce musí mít jasně definovaný začátek!"
      failed= true
    end

    if !Act::EventCategory::multi_day?(record.event_category)
      record.event_end = record.event_start
    end

    if(record.event_end.nil?)
      record.errors[:event_end] << "Akce musí mít jasně definovaný konec!"
      failed = true
    end

    if failed
      return
    end

    if(record.event_start > record.event_end)
      record.errors[:event_end] << "Akce může končit až po svém začátku!"
    end
  end
end

  ##
  # Pokud org zaškrtne, že chce limitovat termín, do kdy mají účastníci upravit status přihlášky na ano/ne a nedá k tomu evný termín, tak ho za to seřvi
class Act::LimitMaybyeValidator < ActiveModel::Validator
  def validate(record)
    if record.limit_maybe && record.maybe_deadline.nil?
      record.errors[:maybe_deadline] << "Pokud chceš účastníky limitovat v tom, do kdy si mají upravit status přihlášky na ano/ne, tak ale nastav jasný termín"
    end
  end
end

  ##
  # Pokud org zaškrtne, že chce limitovat maximální počet účastníků na akci a nezadá žádný konkrétní, tak ho za to seřvi
class Act::LimitNumParticipantsValidator < ActiveModel::Validator
  def validate(record)
    if record.limit_num_participants && (record.max_participants.nil? || !(record.max_participants.is_a? Integer))
      record.errors[:max_participants] << "Pokud chceš limitovat maximální počet účastníků, tak ale nastav jasnou horní hranici"
    end
  end
end

  ##
  # Pokud org zaškrtne, že chce účastníkům umožnit specifikovat místo nástupu na akci a nezadá žádná konkrétní, tak ho za to seřvi
class Act::PlaceValidator < ActiveModel::Validator
  def validate(record)
    if record.spec_place && (record.spec_place_detail.nil? || !(record.spec_place_detail.is_a? String) || record.spec_place_detail.empty?)
      record.errors[:spec_place_detail] << "Pokud chceš, aby účastníci specifikovali místo nástupu, pak jim ale musíš dát z něčeho na výběr"
    end
  end
end

class Act::Event < ActiveRecord::Base
  has_many :event_participants, dependent: :destroy
  has_many :event_invitations, dependent: :destroy
  belongs_to :event_type

  validates :title, presence: true
  validates :activation_needed, inclusion: { in: Act::Participant::OPTIONS_ACTIVATED, message: "Účet musí být aktivován na specifické hodnoty" }
  validates_with Act::StartBeforeEndValidator
  validates_with Act::LimitNumParticipantsValidator
  validates_with Act::PlaceValidator

  VISIBLE_STATUSES = ['everyone', 'user', 'org']

  FILTER_STATUSES = [{ text: "Všechny", code: "all"}, { text: "Jedu", code: "yes"},
                     { text: "Nejedu", code: "no" }, { text: "Nevím", code: "maybe"}, { text: "Nehlasoval jsem", code: "nvt" }]

  ##
  # *Returns* všecny typy akcí vhodné do input type select
  def self.categories_select
    sql = "SELECT name, code, visible FROM act_event_categories ORDER BY idx"
    event_categories = ActiveRecord::Base.connection.execute(sql)
    result = event_categories.map { |category| [category["name"], category["code"]]}
    return result
  end

  ##
  # *Returns* typy akcí, které daný uživatel vidí
  def self.category_filter(current_user)
    sql = "SELECT name, code, visible FROM act_event_categories ORDER BY idx"
    event_categories = ActiveRecord::Base.connection.execute(sql)
    event_categories = event_categories.select {|item| Act::EventCategory::category_visible?(item["visible"], current_user) }
    result = event_categories.map { |category| { text: category["name"], code: category["code"] }}
    return result
  end

  ##
  # *Returns* typy akcí, které daný uživatel vidí + typ "všechny akce"!"
  def self.category_filter_all(current_user)
    categories = Act::Event::category_filter(current_user)
    categories.unshift({ text: 'Všechny', code: 'all'})
    return categories
  end

    # helper method for deciding whether the target event should be visible for the current user
  def event_visible?(user)
    return (user && user.admin?) || ((visible == 'ev' || (user && (user.org? || visible=='user'))) &&
       (Act::EventInvitation::chosen_ps?(self, Act::Participant::get_participant(user)) ||
        ((user.nil? || ! user.org?) && !uninvited_participants_dont_see) || (user && user.org? && !uninvited_organisers_dont_see)))
  end

  ##
  # *Returns* datum konání akce v nějakém čitelném formátu
  def date_str()
    if event_start == event_end
      event_start.strftime('%-d.%-m.%-Y')
    else
      years_equal = event_start.strftime('%-Y') == event_end.strftime('%-Y')
      months_equal = years_equal && (event_start.strftime('%-m') == event_end.strftime('%-m'))

      event_start.strftime('%-d.' + (months_equal ? "" : "%-m.") + (years_equal ? "" : ".%-Y")) + " – " + event_end.strftime('%-d.%-m.%-Y')
    end
  end

  ##
  # *Returns* jestli se daný účastnický účet může této akce zúčastnit jako "participant" (nikoliv jako náhradník)
  def can_participate?(participant)
    event_participant = Act::EventParticipant::get_event_participant(self, participant)
    if participant.admin? || event_participant && event_participant.chosen == "participant" && event_participant.status == "yes"
      return true
    end

    if participant.org? && enable_only_specific_organisers? && ! Act::EventInvitation::chosen_p?(self, participant)
      return false
    end

    if participant.org?
      return true
    end

    if limit_num_participants && num_signed("yes", false, true, true) >= max_participants
      return false
    end

    if !enable_only_specific_participants || Act::EventInvitation::chosen_p?(self, participant)
      return true
    end

    return false
  end

  ##
  # *Returns* jestli na tu akci může jet úplně každý
  def open_for_everyone?()
    return !limit_num_participants && !enable_only_specific_participants && !enable_only_specific_organisers
  end

  ##
  # *Returns* jestli daný účastnický účet je dostatečně aktivovaný pro to, aby se této akce mohl zúčastnit
  def fulfils_activation?(participant)
    return (activation_needed == Act::Participant::ACTIVATION_STATUS_FOR_FULL && participant.act_full?) || (activation_needed == Act::Participant::ACTIVATION_STATUS_FOR_LIGHT && participant.act_light?)
  end

  ##
  # *Returns* jestli se daný účastnický účet může této akce zúčastnit jako náhradník (nikoliv jako účastník)
  def can_substitute?(participant)
   event_participant = Act::EventParticipant::get_event_participant(self, participant)

   if event_participant && event_participant.chosen == "substitute"
     return true
   end

   if participant.org? && enable_only_specific_organisers? && ! Act::EventInvitation::chosen_p?(self, participant)
     return false
   end

   if participant.org?
     return true
   end

   if !enable_only_specific_substitutes || Act::EventInvitation::chosen_ps?(self, participant)
     return true
   end

   return false
  end

  ##
  # *Returns* kolik účastníků je na tuto akci zapsaných daným způsobem
  def num_signed(status, orgs_only, children_only, participants_only=false)
    participants = Act::EventParticipant.where(event_id: id).where(status: status)
    if orgs_only
      participants = participants.select { |p| p.org? }
    end

    if children_only
      participants = participants.select { |p| !(p.org?) }
    end

    if participants_only
      participants = participants.select { |p| p.chosen == "participant" }
    end

    participants.length()
  end

  ##
  # *Returns* sql dotaz pro vyfiltrování těch akcí, které jsou daného typu a an které je účastník přihlášen daným způsobem
  def self.generate_sql(participant, event_category, enroll_status)
    query_start = "SELECT e.* FROM act_events e "

    common_enroll = "JOIN act_event_participants p ON (p.participant_id = ? AND p.event_id = e.id"

    case enroll_status
    when "all"
      query_start += "WHERE "
    when "nvt"
      query_start += "LEFT " + common_enroll + ") WHERE "
    else
      query_start += "INNER " + common_enroll + " AND p.status = ?) WHERE "
    end

    if event_category != "all"
      query_start += "e.event_category = ? AND "
    end

    case enroll_status
    when "all"
      query_end = ""
    when "nvt"
      query_end = "AND p.event_id IS NULL "
    else
      query_end = "AND p.event_id IS NOT NULL "
    end

    query_end += "ORDER BY e.event_start DESC"

    future_query = query_start + "e.event_end >= ? " + query_end
    past_query = query_start + "e.event_end < ? " + query_end

    args_common = []

    if enroll_status != "all"
      args_common.append(participant.id)
    end

    if not ["all", "nvt"].member?(enroll_status)
      args_common.append(enroll_status)
    end

    if event_category != "all"
      args_common.append(event_category)
    end

    args_common.append(Time.current.yesterday())

    args_future = [future_query] + args_common
    args_past = [past_query] + args_common

    return [args_future, args_past]
  end
end

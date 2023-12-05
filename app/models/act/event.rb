  ##
  # TAkce, na kterou se mohou (pokud to organizátoři povolí) přihlašovat účastníci
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

class Act::LimitMaybyeValidator < ActiveModel::Validator
  def validate(record)
    if record.limit_maybe && record.maybe_deadline.nil?
      record.errors[:maybe_deadline] << "Pokud chceš účastníky limitovat v tom, do kdy si mají upravit status přihlášky na ano/ne, tak ale nastav jasný termín"
    end
  end
end

class Act::LimitNumParticipantsValidator < ActiveModel::Validator
  def validate(record)
    if record.limit_num_participants && (record.max_participants.nil? || !(record.max_participants.is_a? Integer))
      record.errors[:max_participants] << "Pokud chceš limitovat maximální počet účastníků, tak ale nastav jasnou horní hranici"
    end
  end
end

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

  def self.category_filter(current_user)
    sql = "SELECT name, code, visible FROM act_event_categories ORDER BY idx"
    event_categories = ActiveRecord::Base.connection.execute(sql)
    event_categories = event_categories.select {|item| Act::EventCategory::category_visible?(item["visible"], current_user) }
    result = event_categories.map { |category| [category["name"], category["code"]] }
    return result
  end

  def self.category_filter_all(current_user)
    categories = Act::Event::category_filter(current_user)
    categories.append(['Všechny', 'ev'])
    return categories
  end

    # helper method for deciding whether the target event should be visible for the current user
  def event_visible?(user)
    if (! user.nil? && user.admin?) || ((visible == 'ev' || (!user.nil? && (user.org? || visible=='user'))) && (Act::EventInvitation::chosen_ps?(self, Act::Participant::get_participant(user)) || ((user.nil? || ! user.org?) && !uninvited_participants_dont_see) || (user.org? && !uninvited_organisers_dont_see)))
      true
    else
      false
    end
  end

  def date_str()
    if event_start == event_end
      event_start.strftime('%d/%m/%Y')
    else
      event_start.strftime('%d/%m/%Y') + " - " + event_end.strftime('%d/%m/%Y')
    end
  end

  def can_participate?(participant)
    event_participant = Act::EventParticipant::get_event_participant(participant, self)
    if participant.admin? || ! event_participant.nil? && event_participant.chosen == "participant"
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

  def open_for_everyone?()
    return !limit_num_participants && !enable_only_specific_participants && !enable_only_specific_organisers
  end

  def fulfils_activation?(participant)
    return (activation_needed == Act::Participant::ACTIVATION_STATUS_FOR_FULL && participant.act_full?) || (activation_needed == Act::Participant::ACTIVATION_STATUS_FOR_LIGHT && participant.act_light?)
  end

  def can_substitute?(participant)
   event_participant = Act::EventParticipant::get_participant(participant, self)

   if ! event_participant.nil? && event_participant.chosen == "substitute"
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

  def self.generate_sql(participant, event_category, enroll_status)
    query_start = "SELECT e.* FROM act_events e "

    common_enroll = "JOIN act_event_participants p ON (p.participant_id = ? AND p.event_id = e.id"

    case enroll_status
    when "ev"
      query_start += "WHERE "
    when "nvt"
      query_start += "LEFT " + common_enroll + ") WHERE "
    else
      query_start += "INNER " + common_enroll + " AND p.status = ?) WHERE "
    end

    if event_category != "ev"
      query_start += "e.event_category = ? AND "
    end

    case enroll_status
    when "ev"
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

    if enroll_status != "ev"
      args_common.append(participant.id)
    end

    if not ["ev", "nvt"].member?(enroll_status)
      args_common.append(enroll_status)
    end

    if event_category != "ev"
      args_common.append(event_category)
    end

    args_common.append(Time.current.yesterday())

    args_future = [future_query] + args_common
    args_past = [past_query] + args_common

    return [args_future, args_past]
  end
end

  ##
  # Účastnický účet umožňující uživateli jezdit na akce. Může být buďto
  # - neaktivován (activaed == "desact") ... pak uživatel nemůže jezdit nikam, (ale stále může být na nějakou akci pozván)
  # - light (activated == "light") ... pak se může uživatel účastnit pouze některých akcí, typicky jednodenních
  # - plně aktivován (activated == "full") .. pak se může uživatel účastnit všech standardních akcí
  #
  # *Columns*
  #    t.belongs_to "user"
  #    t.string     "name"
  #    t.string     "last_name"
  #    t.string     "nickname",         :default => ""
  #    t.string     "sex,"              :default => "male"
  #    t.datetime   "birth"
  #    t.integer    "grade"
  #    t.string     "address"
  #    t.string     "email"
  #    t.string     "parent_email"
  #    t.string     "phone"
  #    t.string     "parent_phone"
  #    t.text       "eating_habits",    :default => ""
  #    t.text       "health_problems",  :default => ""
  #    t.text       "birth_number"
  #    t.string     "health_insurance"
  #    t.string     "activated",        :default => "full"           index: true
  
class Act::Participant < ActiveRecord::Base
  belongs_to :user
  validates_associated :user

  has_many :event_participants, dependent: :destroy
  has_many :event_invitations, dependent: :destroy

  ACTIVATION_STATUS_FOR_FULL = "full"
  ACTIVATION_STATUS_FOR_LIGHT = "light"
  ACTIVATION_STATUS_FOR_DESACTIVATED = "desact"

  OPTIONS_ACTIVATED = [ ACTIVATION_STATUS_FOR_FULL, ACTIVATION_STATUS_FOR_LIGHT, ACTIVATION_STATUS_FOR_DESACTIVATED ]

  OPTIONS_ACTIVATED_TXT = { ACTIVATION_STATUS_FOR_FULL => "Všechny", ACTIVATION_STATUS_FOR_LIGHT => "Pouze jednodenní", ACTIVATION_STATUS_FOR_DESACTIVATED => "Zatím žádné" }

  OPTIONS_ACTIVATED_PROMPT = [[ OPTIONS_ACTIVATED_TXT[ACTIVATION_STATUS_FOR_FULL], ACTIVATION_STATUS_FOR_FULL ], [ OPTIONS_ACTIVATED_TXT[ACTIVATION_STATUS_FOR_LIGHT], ACTIVATION_STATUS_FOR_LIGHT ]]


  validates :activated, inclusion: { in: OPTIONS_ACTIVATED, message: "Účet musí být aktivován na specifické hodnoty" }
  validates :name, presence: true
  validates :last_name, presence: true

  validates :nickname, uniqueness: { case_sensitive: false, message: "tuhle přezdívku už někdo má" }, unless: "nickname == ''"

  with_options if: :act_light? do 
    validates :grade, presence: true, numericality: { only_integer: true, message: "musí být číslo" }
    validates :email, presence: true, uniqueness: { case_sensitive: false, message: 'Tento email již někdo používá. Pokud vlastníš uživatelský účet s tímto emailem, tak se před výtvořením účtu přihlaš.' }
    validates :phone, presence: true
    validates :parent_email, presence: true
    validates :parent_phone, presence: true
  end
  
  with_options if: :act_full? do
    validates :birth, presence: true
    validates :address, presence: true
    validates :birth_number, presence: true
    validates :health_insurance, presence: true
    validates :sex, presence: true
  end

  GRADES = [ "6", "7", "8", "9" ]
  GRADES_TXT = { "4" => "Čtvrtá", "5" => "Pátá", "6" => "Prima", "7" => "Sekunda", "8" => "Tercie", "9" => "Kvarta", "10" => "Kvinta"}

  YOUNGEST_TO_FILTER = 6
  OLDEST_TO_FILTER = 9

  ##
  # *Returns* je účet plně aktivován?
  def act_full?()
    return activated == ACTIVATION_STATUS_FOR_FULL
  end

  ##
  # *Returns* je účet aktivován jakožto "light"?
  def act_light?()
    return activated == ACTIVATION_STATUS_FOR_LIGHT || activated == ACTIVATION_STATUS_FOR_FULL
  end

  ##
  # *Returns* je účet desaktivován?
  def act_no?()
    return activated == ACTIVATION_STATUS_FOR_DESACTIVATED
  end

  ##
  # *Returns* je účet desaktivován?
  def self.has_participant?(user)
    return user && user.participant
  end

  ##
  # *Returns* patří účet orgovi?
  def org?()
    return user && user.org?
  end

  ##
  # *Returns* patří účet adminovi?
  def admin?()
    return user && user.admin?
  end

  ##
  # *Returns* id účastnického účtu patřícího danému uživateli
  def self.participant_id(user)
    if user.nil? || user.participant.nil?
      return nil
    else
      return user.participant.id
    end
  end

  ##
  # *Returns* patří tento účastnický účet zadanému uživatelskému účtu?
  def is_me?(user)
    if user.nil?
      return false
    else
      return user.id.to_s == user_id.to_s
    end
  end

  ##
  # *Returns* účastnický účet zadaného uživatele, pokud existuje. Jinak nil.
  def self.get_participant(user)
    if user.nil?
      return nil
    else
      return user.participant
    end
  end

  ##
  # *Returns* přezdívka (pokud neexistuje, tak jméno a přijmení) tohoto účastnického účtu
  def participant_name
    if not nickname == ""
      "#{nickname}"
    elsif name  && last_name
      "#{name} #{last_name}"
    elsif name
      "#{name}"
    elsif last_name
        "#{last_name}"
    else
      email.split('@',2)[0]
    end
  end

  ##
  # *Returns* datum narození čitelně
  def birth_str
    begin
      return birth.strftime('%d.%m.%Y')
    rescue
      "Nedefinované"
    end
  end

  ##
  # *Returns* jedná se o muže?
  def male?
    sex == "male"
  end

  ##
  # *Returns* pohlaví čitelně
  def sex_str()
    male? ? "Muž" : "Žena"
  end

  ATTR_TABLE =
    {
      id: "Id",
      user_id: "User id",
      name: "Jméno",
      last_name: "Příjmení",
      nickname: "Přezdívka",
      sex: "Pohlaví",
      birth: "Datum narození",
      grade: "Ročník",
      address: "Adresa",
      email: "Email",
      parent_email: "Email na zákonného zástupce",
      phone: "Telefonní číslo",
      parent_phone: "Telefonní číslo na zákonného zástupce",
      eating_habits: "Stravovací návyky",
      health_problems: "Zdravotní problémy",
      birth_number: "Rodné číslo",
      health_insurance: "Zdravotní pojišťovna",
      activated: "Účet aktivováni"
    }

  ATTR_BOOL_TABLE = {}
  for key in ["name", "last_name", "grade", "address", "email", "eating_habits", "phone", "health_problems", "birth_number"] do
    ATTR_BOOL_TABLE[key] = "true"
  end

  ##
  # *Returns* chybová hláška pro danou kolonku
  def self.display_error_msg(error)
    case error
    when :grade
      response = 'Kolonka "Ročník" nesmí být prázdná a její hodnota musí být číslo!'
    else
      response = "Kolonka "
      response += '"' + ATTR_TABLE[error] + '"'
      response += " nesmí být prázdná!"
    end

    return response
  end

  ##
  # *Returns* účastnické účty, které jsou pozvané daným způsobem
  def self.find_by_invitation(event, chosen, role)
    query1 = "SELECT s.* FROM act_participants s WHERE "
    query2 = "EXISTS (SELECT si.* FROM act_event_invitations si WHERE si.participant_id = s.id AND si.event_id = ? AND (si.chosen = ?"
    case chosen
    when "participant"
      participants = Act::Participant.find_by_sql([query1 + query2 + "))", event.id, "participant"])
    when "substitute"
      participants = Act::Participant.find_by_sql([query1 + query2 + "))", event.id, "substitute"])
    when "ev"
      participants = Act::Participant.find_each
    else
      participants = Act::Participant.find_by_sql([query1 + "NOT " + query2 + " OR si.chosen = ?))", event.id, "participant", "substitute"])
    end
    if role == "p"
      return participants.select{|s| ! s.org? }
    else
      return participants.select{|s| s.org? }
    end
  end

  ##
  # *Returns* účastnické účty, které jsou přihlášené daným způsobem
  def self.find_by_participation(event, status, chosen, role)
    query = "SELECT p.* FROM act_participants p "
    args = []

    if status == "nvt"
      query += "WHERE NOT EXISTS (SELECT ep.* FROM act_event_participants ep WHERE ep.event_id = ? AND ep.participant_id = p.id)"
      args << event.id
    else
      if status != "ev" || chosen != "ev"
        query += "INNER JOIN act_event_participants ep ON ep.participant_id = p.id AND ep.event_id = ? WHERE "
        args << event.id
      end

      if status != "ev"
        query += "ep.status = ? " + (chosen != "ev" ? "AND " : "")
        args << status
      end

      if chosen != "ev"
        query += "ep.chosen = ? "
        args << chosen
      end
    end
    
    args.unshift(query)

    participants = Act::Participant.find_by_sql(args)

    case role
    when 'p'
      participants = participants.select{|s| ! s.org?}
    when 'o'
      participants = participants.select{|s| s.org?}
    end

    return participants
  end
end

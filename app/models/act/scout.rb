class Act::Scout < ActiveRecord::Base
  belongs_to :user
  has_many :event_participants, dependent: :destroy
  has_many :event_invitations, dependent: :destroy

  validates :name, presence: true
  validates :last_name, presence: true
  validates :birth, presence: true
  validates :nickname, uniqueness: { case_sensitive: false, message: "tuhle přezdívku už někdo má" }
  validates :grade, presence: true, numericality: { only_integer: true, message: "musí být číslo" }
  validates :address, presence: true
  validates :email, presence: true
  validates :parent_email, presence: true
  validates :phone, presence: true
  validates :parent_phone, presence: true
  validates :birth_number, presence: true
  validates :health_insurance, presence: true
  validates :sex, presence: true
  validates :activated, presence: true

  validates_associated :user

  GRADES = ["6", "7", "8", "9"]
  GRADES_TXT = { "4" => "čtvrtá", "5" => "pátá", "6" => "prima", "7" => "sekunda", "8" => "tercie", "9" => "kvarta", "10" => "kvinta"}

  YOUNGEST_TO_FILTER = 6
  OLDEST_TO_FILTER = 9

  def self.scouts?(user)
    return !user.nil? && !user.scout.nil?
  end

  def org?()
    return user.org?
  end

  def self.scout_id(user)
    if user.nil? || user.scout.nil?
      return nil
    else
      return user.scout.id
    end
  end

  def self.get_scout_path(user)
    if Act::Scout::scouts?(user)
      return '/act/scouts/' + Act::Scout::scout_id(user).to_s
    else
      return '/act/scouts/new'
    end
  end

  def is_me?(user)
    if user.nil?
      return false
    else
      return user.id.to_s == user_id.to_s
    end
  end

  def self.get_scout(user)
    if user.nil?
      return nil
    else
      return user.scout
    end
  end

  def scout_name
    if not nickname == ""
      "#{nickname}"
    elsif !name.nil?  && !last_name.nil?
      "#{name} #{last_name}"
    elsif !name.nil?
      "#{name}"
    elsif !last_name.nil?
        "#{last_name}"
    else
      email.split('@',2)[0]
    end
  end

  def birth_str
    begin
      return birth.strftime('%m/%d/%Y')
    rescue
      "Nedefinované"
    end
  end

  def male?
    sex == "male"
  end

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
      sex: "Pohlav:í",
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

  def self.find_by_invitation(event, chosen, role)
    query1 = "SELECT s.* FROM act_scouts s WHERE "
    query2 = "EXISTS (SELECT si.* FROM act_event_invitations si WHERE si.scout_id = s.id AND si.event_id = ? AND (si.chosen = ?"
    case chosen
    when "participant"
      scouts = Act::Scout.find_by_sql([query1 + query2 + "))", event.id, "participant"])
    when "substitute"
      scouts = Act::Scout.find_by_sql([query1 + query2 + "))", event.id, "substitute"])
    when "ev"
      scouts = Act::Scout.find_each
    else
      scouts = Act::Scout.find_by_sql([query1 + "NOT " + query2 + " OR si.chosen = ?))", event.id, "participant", "substitute"])
    end
    if role == "p"
      return scouts.select{|s| ! s.org? }
    else
      return scouts.select{|s| s.org? }
    end
  end

  def self.find_by_participation(event, status, chosen, role)
    query = "SELECT s.* FROM act_scouts s "
    args = []

    if status == "nvt"
      "WHERE NOT EXISTS (SELECT ep.* FROM act_event_participants ep WHERE ep.event_id = ? AND ep.scout_id = s.id)"
      args << event.id
    else
      if status != "ev" || chosen != "ev"
        query += "INNER JOIN act_event_participants ep ON ep.scout_id = s.id AND ep.event_id = ? WHERE "
        args << event.id
      end

      if status != "ev"
        query += "ep.status = ? " + (chosen != "ev" ? "AND " : "")
        args << role
      end

      if chosen != "ev"
        query += "ep.chosen = ? "
        args << chosen
      end
    end
    
    args.unshift(query)

    scouts = Act::Scout.find_by_sql(args)

    case role
    when 'p'
      scouts = scouts.select{|s| ! s.org?}
    when 'o'
      scouts = scouts.select{|s| s.org?}
    end

    return scouts
  end
end

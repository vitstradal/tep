class Scout < ActiveRecord::Base
  belongs_to :user, inverse_of: :scout
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

  GRADES = ["4", "5", "6", "7", "8", "9", "10"]
  GRADES_TXT = { "4" => "čtvrtá", "5" => "pátá", "6" => "prima", "7" => "sekunda", "8" => "tercie", "9" => "kvarta", "10" => "kvinta"}

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
    if Scout::scouts?(user)
      return '/scouts/' + Scout::scout_id(user).to_s
    else
      return '/scouts'
    end
  end

  def is_me?(user)
    if user.nil?
      return false
    else
      return Scout::scout_id(user).to_i == "#{id}".to_i
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
    birth.strftime('%m/%d/%Y')
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
    query1 = "SELECT s.* FROM scouts s WHERE "
    query2 = "EXISTS (SELECT si.* FROM event_invitations si WHERE si.scout_id = s.id AND si.event_id = ? AND (si.chosen = ?"
    case chosen
    when "participant"
      scouts = Scout.find_by_sql([query1 + query2 + "))", event.id, "participant"])
    when "substitute"
      scouts = Scout.find_by_sql([query1 + query2 + "))", event.id, "substitute"])
    when "ev"
      scouts = Scout.find_each
    else
      scouts = Scout.find_by_sql([query1 + "NOT " + query2 + " OR si.chosen = ?))", event.id, "participant", "substitute"])
    end
    if role == "p"
      return scouts.select{|s| ! s.org? }
    else
      return scouts.select{|s| s.org? }
    end
  end
end

class Scout < ActiveRecord::Base
  belongs_to :user, inverse_of: :scout
  has_many :event_participants, dependent: :destroy

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

  validates_associated :user

  def self.scouts?(user)
    return !user.nil? && !user.scout.nil?
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

  def full_name
    if !nickname.nil?
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

  ATTR_TABLE =
    {
      id: "Id",
      user_id: "User id",
      name: "Jméno",
      last_name: "Příjmení",
      nickname: "Přezdívka",
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
      activated: "Účet aktivován"
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

end

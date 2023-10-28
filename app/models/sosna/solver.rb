##
# Třída reprezentující tabulku sosna_solver, řešitele.
#
# Pozor: řešitel je v každém ročníku nový, neplést s uživatelem,
# Tedy jeden uživatel může mít i více řešitelů, nebo žádného.
# Každý řešitel by měl mít alepsoň jedno uživatele.
#
# *Colums*
#    t.text     "name"
#    t.text     "last_name"
#    t.text     "sex",            default: "male"
#    t.text     "birth"
#    t.text     "where_to_send",  default: "home"
#    t.text     "grade"
#    t.text     "grade_num"
#    t.text     "finish_year"
#    t.text     "annual"
#    t.text     "email"
#    t.text     "street"
#    t.text     "num"
#    t.text     "city"
#    t.text     "psc"
#    t.text     "state"
#    t.integer  "user_id"
#    t.integer  "school_id"
#    t.datetime "created_at"
#    t.datetime "updated_at"
#    t.text     "solution_form",  default: "tep"
#    t.boolean  "is_test_solver", default: false,  null: false
#    t.text     "country",        default: "cz"
#    t.text     "confirm_state",  default: "none"
#    t.text     "how_i_met_pikomat",  default: ""
class Sosna::Solver < ActiveRecord::Base

  has_many :solutions
  belongs_to :school
  belongs_to :user

  JUNIOR_LEVEL = 'jr'
  MAX_GRADE = 9
  NORMAL_LEVEL = 'pi'
  LEVELS = [ NORMAL_LEVEL, JUNIOR_LEVEL ]
  LEVEL_MAP = {
     JUNIOR_LEVEL => 'Pikomat junior',
     NORMAL_LEVEL => 'Pikomat',
  }
  LEVEL_TEXT = {
     JUNIOR_LEVEL => ' Junior',
     NORMAL_LEVEL => '',
  }
  LEVEL_MAX_GRADE = {
     JUNIOR_LEVEL => 6,
     NORMAL_LEVEL => 9,
  }


  validates :name, :last_name,  presence: true
  validates :num, :psc, :city, presence: true, :if  => :send_home?
  validates :birth,  format: {with: /\A\Z|\A\d+\.\d+\.\d{4}\Z/, message: :date}
  validates :grade_num,  format: {with: /\A\d*\Z/, message: :number}
  validates :email, format: {with: /\A\Z|\A[-_a-z\d\.\+]+@[a-z\d\.\-]+\Z/i , message: :email}
  #validates_associated :school

  def self.level_from_short(level)
    return NORMAL_LEVEL if level.nil? || level.empty?
    return level if LEVEL_MAP[level]
    return NORMAL_LEVEL
  end

  def self.level_extension(level)
    level_ext = ''
    level_ext = "#{level}" unless @level == NORMAL_LEVEL
    return level_ext
  end

  def self.level_text(level)
    return LEVEL_TEXT[level] || ''
  end

  def self.level_long(level)
    return LEVEL_MAP[level] || ''
  end

  def self.level_valid?(level)
    return LEVEL_MAP.keys.include? level
  end

  def self.max_grade_for_level(level)
    return LEVEL_MAX_GRADE[level] || MAX_GRADE
  end

  ##
  # *Returns* true, falseb
  def user_email_consistent?
     return true if self.user.nil?
     return self.user.email.casecmp(email) == 0
  end

  ##
  # *Returns* email uživatele příslušného k tomuto řešiteli
  def user_email
     return nil if self.user.nil?
     return self.user.email
  end

  ##
  # *Returns* true/false Posílat domů papírově?
  def send_home?
     self.where_to_send == 'home'
  end

  ##
  # *Returns* kombinace sloupců: "#{last_name.strip} #{name.strip}"
  def full_name
     "#{last_name.strip} #{name.strip}"
  end 

  ##
  # *Returns* kombinace sloupců: "#{street} #{num}, #{psc} #{city}"
  def address
     "#{street} #{num}, #{psc} #{city}"
  end

  ##
  # *Returns* je resitel opraven odevdavat ulohy pro mlade, tj 6 ročník anebo
  # mladší
  def junior?
     grade_num.to_i <= 6
  end


end

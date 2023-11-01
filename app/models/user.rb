##
# Třída reprezentující tabulku user, uživatele.
#
# Pozor: řešitel je v každém ročníku nový, neplést s uživatelem,
# Tedy jeden uživatel může mít i více řešitelů, nebo žádného.
# Každý řešitel by měl mít alepsoň jedno uživatele.
# 
# Skupiny:
# admin:: admin
# org:: organizator
# user:: běžný uživatel, s největší pravděpodobností řešitel
# guest:: asi se nepoužívá
# sklep:: může přistupovat do sklepa
# morg:: more org
# jabber:: obsolete
# 
# *Colums*
#    t.string   "email",                  limit: 255, default: "", null: false
#    t.string   "encrypted_password",     limit: 255, default: "", null: false
#    t.string   "reset_password_token",   limit: 255
#    t.datetime "reset_password_sent_at"
#    t.datetime "remember_created_at"
#    t.integer  "sign_in_count",                      default: 0
#    t.datetime "current_sign_in_at"
#    t.datetime "last_sign_in_at"
#    t.string   "current_sign_in_ip",     limit: 255
#    t.string   "last_sign_in_ip",        limit: 255
#    t.string   "confirmation_token",     limit: 255
#    t.datetime "confirmed_at"
#    t.datetime "confirmation_sent_at"
#    t.string   "unconfirmed_email",      limit: 255
#    t.integer  "failed_attempts",                    default: 0
#    t.string   "unlock_token",           limit: 255
#    t.datetime "locked_at"
#    t.integer  "roles_mask"
#    t.datetime "created_at"
#    t.datetime "updated_at"
#    t.string   "name",                   limit: 255
#    t.string   "last_name",              limit: 255
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         #:token_authenticatable,
         :confirmable, :lockable, :timeoutable,
         :recoverable, :rememberable, :trackable, :validatable,
         :timeout_in => 60.minutes


  # Setup accessible (or protected) attributes for your model
  #attr_accessible :email, :password, :password_confirmation, :remember_me

  include RoleModel

  # Setup accessible (or protected) attributes for your model
  #attr_accessible :email, :password, :password_confirmation, :remember_me, :roles, :roles_mask

  # optionally set the integer attribute to store the roles in,
  # :roles_mask is the default
  roles_attribute :roles_mask

  has_one :jabber, inverse_of: :user

  # declare the valid roles -- do not change the order if you add more
  # roles later, always append them at the end!
  roles :admin, :org, :user, :guest, :sklep, :morg, :jabber

  before_create do
    roles << :user
  end
  skip_callback :create, :after, :send_confirmation_instructions

  ##
  # *Returns* kominace sloupců "#{full_name} <#{email}>"
  def full_email
    "#{full_name} <#{email}>"
  end

  ##
  # *Returns* kominace sloupců, něco jako "#{name} #{last_name}" pokud dané spouce existují
  def full_name
    if !name.nil?  && !last_name.nil?
      "#{name} #{last_name}"
    elsif !name.nil? 
      "#{name}"
    elsif !last_name.nil? 
      "#{last_name}"
    else
      email.split('@',2)[0]
    end
  end

  ##
  # zašle instrukce pro první přihlášení
  def send_first_login_instructions(is_bonus = false)
     token_raw = set_reset_password_token
     send_devise_notification(:first_login_instructions, token_raw, is_bonus)
  end
end

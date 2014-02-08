class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         #:token_authenticatable, 
         :confirmable, :lockable, :timeoutable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  #attr_accessible :email, :password, :password_confirmation, :remember_me

  include RoleModel

  # Setup accessible (or protected) attributes for your model
  #attr_accessible :email, :password, :password_confirmation, :remember_me, :roles, :roles_mask

  # optionally set the integer attribute to store the roles in,
  # :roles_mask is the default
  roles_attribute :roles_mask

  # declare the valid roles -- do not change the order if you add more
  # roles later, always append them at the end!
  roles :admin, :org, :user, :guest

  before_create do
    roles << :user
  end
  skip_callback :create, :after, :send_confirmation_instructions

  def full_email
    "#{full_name} <#{email}>"
  end
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

  def send_first_login_instructions
     #self.generate_reset_password_token!
     #self.send_devise_notification(:first_login_instructions)
     #print("mailer:", pp(mailer), "\n")
     #d.deliver
     #mailer.first_login_instructions(self, {})
     #opts = {}
     #self.send_devise_notification(:first_login_instructions, opts)

     raw, enc = Devise.token_generator.generate(self.class, :reset_password_token)

     self.reset_password_token   = enc
     self.reset_password_sent_at = Time.now.utc
     self.save(:validate => false)

     devise_mailer.first_login_instructions(self).deliver

  end
end

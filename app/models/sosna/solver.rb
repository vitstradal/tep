class Sosna::Solver < ActiveRecord::Base
  has_many :solutions
  belongs_to :school
  belongs_to :user

  validates :name, :last_name,  presence: true
  validates :num, :psc, :city, presence: true, :if  => :send_home?
  validates :birth,  format: {with: /\A\Z|\A\d+\.\d+.\d{4}\Z/, message: :date}
  validates :grade_num,  format: {with: /\A\d*\Z/, message: :number}
  validates :email, format: {with: /\A\Z|\A[-_a-z\d\.]+@[a-z\d\.\-]+\Z/i , message: :email}
  #validates_associated :school

  def user_email_consistent?
     return true if self.user.nil?
     return self.user.email == email
  end

  def send_home?
     self.where_to_send == 'home'
  end
  def full_name
     "#{name} #{last_name}"
  end 
  def address
     "#{street} #{num}, #{psc} #{city}"
  end
end

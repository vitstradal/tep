class Sosna::Solver < ActiveRecord::Base
  has_many :solutions
  belongs_to :school
  belongs_to :user

  validates :name, :last_name, :num, :birth, :psc, :city, presence: true
  validates :birth,  format: {with: /\d+\.\d+.\d{4}/, message: :date}
  validates :email, format: {with: /[a-z\d\.\-]+@[a-z\d\.\-]+/i , message: :email}
  #validates_associated :school

  def full_name
     "#{name} #{last_name}"
  end 
  def address
     "#{street} #{num}, #{psc} #{city}"
  end
end

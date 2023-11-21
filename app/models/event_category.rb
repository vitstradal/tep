require 'pp'

class EventCategory < ActiveRecord::Base
  self.primary_key = :code

  has_many :events
  has_many :event_participants, through: :events

  validates :code, :presence => true, uniqueness: { case_sensitive: false,  message: "Kódy jednotlivých typů akcí musí být unikátní!" }
  validates :name, :presence => true
  validates :visible, :presence => true

  def self.category_unique(new_code, old_code)
    records_array = EventCategory.where(code: new_code)

    if records_array.length() == 0 || new_code == old_code
      true
    else
      false
    end
  end

  VISIBLE_STATUSES = ['ev', 'user', 'org']
  VISIBLE_STATUSES_TXT = { 'ev' => 'Každý', 'user' => 'Uživatel', 'org' => 'org' }

  def self.category_visible?(visibility_status, current_user)
    if(visibility_status == 'ev' || current_user && (current_user.org? || (current_user.user? && visibility_status=='user')))
      true
    else
      false
    end
  end

  def multi_day_txt()
    multi_day ? "Ano" : "Ne"
  end

  def visible_txt()
    VISIBLE_STATUSES_TXT[visible]
  end
end

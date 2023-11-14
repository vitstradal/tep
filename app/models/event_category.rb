require 'pp'

class EventCategory < ActiveRecord::Base
  self.primary_key = :code

  has_many :events
  has_many :event_participants, through: :events

  validates :code, :presence => true, uniqueness: { case_sensitive: false,  message: "Kódy jednotlivých typů akcí musí být unikátní!" }
  validates :name, :presence => true

  def self.category_unique(new_code, old_code)
    records_array = EventCategory.where(code: new_code)

    if records_array.length() == 0 || new_code == old_code
      true
    else
      false
    end
  end
end

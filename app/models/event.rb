##
# Třída reprezentující tabulku přihlášených a popř. nějaké krátké info ohledně akce.
#

class Event < ActiveRecord::Base
  has_many :event_participants, dependent: :destroy

  validates :title, presence: true
  validates :event_start, presence: true
  validates :event_end, presence: true

  VISIBLE_STATUSES = ['everyone', 'user', 'org']

  CATEGORIES = [['Víkendovka', 'wk'], ['Pikostředa', 'we'], ['Jiné', 'ot']]
  CATEGORY_SEARCH = CATEGORIES.clone.unshift(['Všechny', 'ev'])

    # helper method for deciding whether the target event should be visible for the current user
  def self.event_visible?(visibility_status, current_user)
    if(visibility_status == 'everyone' || current_user && (current_user.org? || (current_user.user? && visibility_status=='user')))
      true
    else
      false
    end
  end

  def date_str()
    if event_start == event_end
      event_start.strftime('%m/%d/%Y')
    else
      event_start.strftime('%m/%d/%Y') + event_end.strftime('%m/%d/%Y')
    end
  end
end

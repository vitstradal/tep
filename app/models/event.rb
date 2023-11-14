##
# Třída reprezentující tabulku přihlášených a popř. nějaké krátké info ohledně akce.
#
#
require 'pp'

class Event < ActiveRecord::Base
  has_many :event_participants, dependent: :destroy
  belongs_to :event_type

  validates :title, presence: true
  validates :event_start, presence: true
  validates :event_end, presence: true

  VISIBLE_STATUSES = ['everyone', 'user', 'org']

  #CATEGORIES = [['Víkendovka', 'wk'], ['Pikostředa', 'we'], ['Jiné', 'ot']]
  #CATEGORY_SEARCH = CATEGORIES.clone.unshift(['Všechny', 'ev'])
  def self.category_filter()
    sql = "SELECT name, code FROM event_categories ORDER BY idx"
    event_categories = ActiveRecord::Base.connection.execute(sql)
    result = event_categories.map { |category| [category["name"], category["code"]] }
    return result
  end

  def self.category_filter_all()
    categories = Event::category_filter()
    categories.append(['Všechny', 'ev'])
    return categories
  end

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
      event_start.strftime('%m/%d/%Y') + " - " + event_end.strftime('%m/%d/%Y')
    end
  end

  def self.generate_sql(scout, event_category, enroll_status)
    query_start = "SELECT e.* FROM events e "

    common_enroll = "JOIN event_participants p ON (p.scout_id = ? AND p.event_id = e.id"

    case enroll_status
    when "ev"
      query_start += "WHERE "
    when "nvt"
      query_start += "LEFT " + common_enroll + ") WHERE "
    else
      query_start += "INNER " + common_enroll + " AND p.status = ?) WHERE "
    end

    if event_category != "ev"
      query_start += "e.event_category = ? AND "
    end

    case enroll_status
    when "ev"
      query_end = ""
    when "nvt"
      query_end = "AND p.id IS NULL "
    else
      query_end = "AND p.id IS NOT NULL "
    end

    query_end += "ORDER BY e.event_start DESC"

    future_query = query_start + "e.event_end >= ? " + query_end
    past_query = query_start + "e.event_end < ? " + query_end

    args_common = []

    if enroll_status != "ev"
      args_common.append(scout.id)
    end

    if not ["ev", "nvt"].member?(enroll_status)
      args_common.append(enroll_status)
    end

    if event_category != "ev"
      args_common.append(event_category)
    end

    args_common.append(Time.current)

    args_future = [future_query] + args_common
    args_past = [past_query] + args_common

    return [args_future, args_past]
  end
end

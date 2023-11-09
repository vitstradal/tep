class Scout < ActiveRecord::Base
  belongs_to :user, inverse_of: :scout
  has_many :event_participants

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

  def is_me(user)
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

end

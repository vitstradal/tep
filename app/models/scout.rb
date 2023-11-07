class Scout < ActiveRecord::Base
  belongs_to :user

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

end

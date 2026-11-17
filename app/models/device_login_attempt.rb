class DeviceLoginAttempt < ActiveRecord::Base
  PER_MIN = 5
  PER_HOUR = 20

  def self.begin!(user)
    attempt = create!(user_id: user.id, ok: false)
    now = Time.current
    failed = where(user_id: user.id, ok: false)
    return nil if failed.where('created_at > ?', now - 1.minute).count > PER_MIN
    return nil if failed.where('created_at > ?', now - 1.hour).count > PER_HOUR

    attempt
  end

  def succeed!
    update!(ok: true)
  end
end

require 'ipaddr'

class DeviceLogin < ActiveRecord::Base
  class Busy < StandardError; end

  ICONS = [
    ['🍎', 'jablko'], ['🍌', 'banán'], ['🍇', 'hrozny'], ['🍉', 'meloun'], ['🥕', 'mrkev'], ['🍕', 'pizza'],
    ['🍄', 'houba'], ['🌵', 'kaktus'], ['🌻', 'slunečnice'], ['🌙', 'měsíc'], ['⭐', 'hvězda'], ['🔥', 'oheň'],
    ['🐘', 'slon'], ['🐟', 'ryba'], ['🐢', 'želva'], ['🐝', 'včela'], ['🐧', 'tučňák'], ['🦋', 'motýl'],
    ['🚗', 'auto'], ['🚲', 'kolo'], ['🚀', 'raketa'], ['⚽', 'míč'], ['🎸', 'kytara'], ['🔑', 'klíč']
  ].freeze

  TTL = 5.minutes
  APPROVE_TTL = 2.minutes
  MAX_PENDING = 500
  IP_LIMIT = 30
  CODE_ATTEMPTS = 10

  belongs_to :user, optional: true

  scope :valid_pending, -> { where(state: 'pending').where('expires_at > ?', Time.current) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.ip_bucket(ip)
    addr = IPAddr.new(ip.to_s).native
    addr.ipv6? ? "#{addr.mask(64)}/64" : addr.to_s
  rescue IPAddr::Error
    ip.to_s
  end

  def self.create_for!(token:, user_agent:, ip:, return_to:)
    now = Time.current
    bucket = ip_bucket(ip)

    where('created_at < ?', now - 1.day).delete_all
    raise Busy if valid_pending.count >= MAX_PENDING
    raise Busy if where(ip_bucket: bucket).where('created_at > ?', now - 1.hour).count >= IP_LIMIT

    code = CODE_ATTEMPTS.times.lazy.map { random_code }.find { |c| !valid_pending.exists?(code: c) }
    raise Busy unless code

    create!(code: code, state: 'pending', device_digest: digest(token), user_agent: user_agent,
            ip: ip, ip_bucket: bucket, return_to: return_to, expires_at: now + TTL)
  end

  def self.random_code
    Array.new(4) { SecureRandom.random_number(ICONS.size) }.join('-')
  end

  def self.find_pending(indices)
    return nil unless indices.is_a?(Array) && indices.size == 4
    return nil unless indices.all? { |i| i.is_a?(Integer) && i >= 0 && i < ICONS.size }

    valid_pending.order(id: :desc).find_by(code: indices.join('-'))
  end

  def self.for_device(token)
    where(device_digest: digest(token)).order(id: :desc).first
  end

  def icons
    code.split('-').map { |i| ICONS[i.to_i] }
  end

  def approve!(user)
    now = Time.current
    changes = { state: 'approved', user_id: user.id, approved_at: now, updated_at: now }
    transition(self.class.where(state: 'pending').where('expires_at > ?', now), changes)
  end

  def finish!(token)
    now = Time.current
    scope = self.class.where(state: 'approved', device_digest: self.class.digest(token))
                      .where('approved_at > ?', now - APPROVE_TTL)
    transition(scope, state: 'done', updated_at: now)
  end

  def cancel!(from: %w[pending approved])
    transition(self.class.where(state: from), state: 'cancelled', updated_at: Time.current)
  end

  def device_label
    "#{device_os} · #{device_browser}"
  end

  def same_network?(other_ip)
    self.class.ip_bucket(other_ip) == ip_bucket
  end

  def expires_in
    [(expires_at - Time.current).ceil, 0].max
  end

  def approve_expires_in
    return 0 unless state == 'approved' && approved_at

    [(approved_at + APPROVE_TTL - Time.current).ceil, 0].max
  end

  private

  def transition(scope, changes)
    return false unless scope.where(id: id).update_all(changes) == 1

    changes.each { |attr, value| self[attr] = value }
    clear_changes_information
    true
  end

  def device_os
    case user_agent.to_s
    when /Android/ then 'Android'
    when /iPhone/ then 'iPhone'
    when /iPad/ then 'iPad'
    when /Windows/ then 'Windows'
    when /Macintosh|Mac OS/ then 'Mac'
    when /Linux/ then 'Linux'
    else 'neznámý systém'
    end
  end

  def device_browser
    case user_agent.to_s
    when %r{Edg/} then 'Edge'
    when %r{Firefox/} then 'Firefox'
    when %r{Chrome/|CriOS/} then 'Chrome'
    when %r{Safari/} then 'Safari'
    else 'neznámý prohlížeč'
    end
  end
end

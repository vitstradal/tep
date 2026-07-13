##
# Přítel Pikomatu — identita v kvízovém světě (viz navrh-kvizy-a-pratele.md).
#
# uuid drží prohlížeč v localStorage; dokud user_id je NULL, jde o anonymního
# přítele. Po registraci se doplní user_id (unikátní — každý uživatel má
# právě jednoho přítele). Nick je jediný zdroj pravdy pro výsledkovky,
# i po registraci.
class Friend < ActiveRecord::Base
  belongs_to :user, optional: true
  has_many :quiz_answers, dependent: :destroy

  validates :uuid, presence: true, uniqueness: true
  validates :nick, presence: true, length: { maximum: 40 }
  validates :user_id, uniqueness: true, allow_nil: true

  before_validation do
    self.uuid ||= SecureRandom.uuid
    self.nick = nick.to_s.strip
  end

  ##
  # 'anonymous' | 'unverified' | 'verified' — viz žebřík identit v návrhu
  def status
    return 'anonymous' if user.nil?
    user.confirmed_at ? 'verified' : 'unverified'
  end

  ##
  # Krátký veřejný rozlišovač kolizí nicků (Petr ·a3). Hash z uuid,
  # ne uuid samotné, aby neuniklo.
  def discriminator
    Digest::SHA1.hexdigest(uuid.to_s)[0, 2]
  end

  ##
  # Nick pro výsledkovku (moderace: skrytý friend je 'anonym')
  def display_nick
    hidden ? 'anonym' : nick
  end
end

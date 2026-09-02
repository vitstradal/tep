##
# Třída reprezentující tabulku sosna_school, školu
#
# *Colums*
#    t.text    "name"
#    t.text    "short"
#    t.text    "street"
#    t.text    "num"
#    t.text    "city"
#    t.text    "psc"
#    t.text    "state"
#    t.text    "universal_id"
#    t.boolean "want_paper",   default: false, null: false
#    t.text    "country",      default: "cz"
class Sosna::School < ActiveRecord::Base
  has_many :solvers
  validates :name, :psc, :city, presence: true
  #validates_uniqueness_of :short

  ##
  # *Returns* adresa zkombinovana z ostatních položek "#{street} #{num}, #{psc} #{city}"
  def address
     "#{street} #{num}, #{psc} #{city}"
  end

  ##
  # *Returns* zkracene jmeno na 20 znaku
#  def name_short
#
#    namep[0..19]
#  end

  ##
  # *Returns* dlouha adresa adresa zkombinovana z ostatních položek "#{city}, #{name}, #{street} #{num}, #{psc} "
  def long
     "#{city}, #{name}, #{street} #{num}, #{psc} "
  end

  # Města, jejichž pomlčková/číslovaná část se slučuje pod základ
  # (Ostrava-Vítkovice → Ostrava). Whitelist proto, aby nespadl
  # Frýdek-Místek a spol., kde pomlčka NENÍ městská část.
  PART_CITIES = ['Praha', 'Brno', 'Ostrava', 'Plzeň'].freeze

  ##
  # Město pro seskupování ve výběru školy: „Praha 5", „Praha 4 - Modřany"
  # → „Praha"; „Ostrava-Vítkovice" → „Ostrava" (viz PART_CITIES); obecně
  # se uřízne koncové číslo („Město 2" → „Město"). Pomlčková města mimo
  # whitelist zůstávají celá (Frýdek-Místek, Kostelec nad Labem...).
  def city_group
    c = city.to_s.strip
    return '' if c !~ /\p{L}/   # pseudo-školy (DOM, PRE) mají město '-'
    PART_CITIES.each do |base|
      return base if c =~ /\A#{base}\s*(\d|[-–])/
    end
    c.sub(/\s+\d+.*$/, '')
  end

  ##
  # Zkrácená městská část pro text ve výběru školy: „Praha 10" → „P10",
  # „Ostrava-Vítkovice" → „O-Vítkovice". Když město část nemá (city ==
  # city_group), vrací nil — město pak v textu není (říká ho filtr).
  def city_part_short
    c = city.to_s.strip
    g = city_group
    return nil if g.empty? || c == g
    rest = c[g.length..].to_s.strip.sub(/\A[-–]\s*/, '-')
    "#{g[0]}#{rest}"
  end

  ##
  # Text opce ve výběru školy (bez města, resp. jen se zkrácenou částí).
  def select_label
    [city_part_short, "#{name}, #{street} #{num}, #{psc}", short].compact.join(', ')
  end
end

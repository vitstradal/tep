##
# Kvíz, adventní kalendář nebo anketa (viz navrh-kvizy-a-pratele.md).
#
# quiz_type:: 'quiz' | 'advent' | 'poll'
# name:: čitelný identifikátor do URL i wiki ('advent-2026')
# data:: jsonb — definice otázek, správné odpovědi ({'correct' => {'1' => '42'}}), nastavení
class Quiz < ActiveRecord::Base
  has_many :quiz_answers, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :quiz_type, inclusion: { in: %w[quiz advent poll] }, allow_nil: true

  ##
  # Jsou výsledky veřejné? Rozhoduje organizátor per kvíz
  # (data['public_results']); default je soukromé — vidí jen org.
  def results_public?
    !!(data && data['public_results'])
  end

  ##
  # Je kvíz otevřený (lze odpovídat)?
  def open?(today = Date.today)
    (opens_on.nil? || opens_on <= today) && (closes_on.nil? || closes_on >= today)
  end

  ##
  # Advent: otázka (den) question_no se odemyká až opens_on + (question_no - 1).
  # Ostatní typy: stačí otevřený kvíz.
  def question_open?(question_no, today = Date.today)
    return false unless open?(today)
    return true unless quiz_type == 'advent'
    return false if opens_on.nil? || question_no.nil?
    opens_on + (question_no - 1) <= today
  end
end

##
# Třída reprezentující tabulku sosna_result, výsledek řešitele k dané serii. Obsahuje počet bodů i pořadí v sérii i celkově.
#
# *Colums*
#    t.integer  "annual"
#    t.integer  "round"
#    t.integer  "solver_id"
#    t.text     "comment"
#    t.integer  "score"
#    t.integer  "round_score"
#    t.integer  "rank"
#    t.integer  "rank_to"
#    t.integer  "class_rank"
#    t.integer  "class_rank_to"
#    t.datetime "created_at"
#    t.datetime "updated_at"
class Sosna::Result < ActiveRecord::Base

  belongs_to :solver


  ##
  # je v celkovém pořadí na dané pozici sám, nebo sdílí místo s někým jiným? 
  #
  # *Returns* `false` je sám, `true` sdílí
 
  def rank_multi?
    return false if rank.nil? || rank_to.nil?
    return rank < rank_to
  end

  ##
  # je v pořadí v ročníku na dané pozici sám, nebo sdílí místo s někým jiným? 
  #
  # *Returns* `false` je sám, `true` sdílí
  def class_rank_multi?
    return false if class_rank.nil? || class_rank_to.nil?
    return class_rank < class_rank_to
  end

  ##
  # Vytiskne celkové pořadí
  #
  # *Params*
  # result_last:: [Sosna::Result] pořadí předchozího (pokud je stejné, bude vráceno '') nebo 'nil'
  # begin_page:: true/false pokud je nová stránka vypíše se pořadí bez ohledu na `result_last`
  #
  # *Returns*
  #   '5.--6.' # pokud pořadí sdíleno
  #   '5.'     # poud je sám
  #   ''       # pokud je předchozí pořadí stejné, a není začátek stránky

  def rank_range(result_last = nil, page_begin = false)
    range = rank_multi? ? "#{rank}.--#{rank_to}." : "#{rank}."
    return range if result_last.nil?
    range_last = result_last.rank_range
    return range if page_begin || range != range_last
    return ''
  end
  
  ##
  # Vytiskne pořadí v ročníku
  #
  # *Params*
  # result_last:: [Sosna::Result] pořadí předchozího (pokud je stejné, bude vráceno '') nebo 'nil'
  # begin_page:: true/false pokud je nová stránka vypíše se pořadí bez ohledu na `result_last`
  #
  # *Returns*
  #   '5.--6.' # pokud pořadí sdíleno
  #   '5.'     # poud je sám
  #   ''       # pokud je předchozí pořadí stejné, a není začátek stránky
  def class_rank_range(result_last = nil,page_begin = false)
    class_range = class_rank_multi? ? "#{class_rank}.--#{class_rank_to}." : "#{class_rank}."
    return class_range if result_last.nil?
    class_range_last = result_last.class_rank_range
    return class_range if page_begin || class_range != class_range_last
    return ''
  end

end

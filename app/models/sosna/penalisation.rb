##
# Třída reprezentující tabulku sosna_penalisations, tedy penalizace řešitele v dané serii (za pozdní poslání, nebo opisování)
#
# *Colums*
#    t.integer  "annual"
#    t.integer  "round"
#    t.integer  "solver_id"
#    t.integer  "score"
#    t.text     "title"
#    t.datetime "created_at"
#    t.datetime "updated_at"
class Sosna::Penalisation < ActiveRecord::Base
  belongs_to :solver
end

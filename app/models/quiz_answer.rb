##
# Odpověď přítele na otázku kvízu. Identita vždy přes friend_id
# (i pro přihlášené — viz navrh-kvizy-a-pratele.md).
class QuizAnswer < ActiveRecord::Base
  belongs_to :quiz
  belongs_to :friend

  validates :question_no, uniqueness: { scope: [:quiz_id, :friend_id] }
end

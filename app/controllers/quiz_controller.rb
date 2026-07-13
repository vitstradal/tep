##
# Kvízy a adventomat — příjem odpovědí a výsledkovka
# (viz navrh-kvizy-a-pratele.md).
class QuizController < ApplicationController
  authorize_resource :class => false

  THROTTLE_PER_MINUTE = 30

  ##
  # POST /quiz/:name/answer
  #
  # *Params*
  # name:: identifikátor kvízu (quizzes.name)
  # uuid:: friend uuid (nepovinné, založí se lazy z nick)
  # nick:: přezdívka pro lazy založení
  # question_no:: číslo otázky (advent: den)
  # answer:: odpověď
  # website:: honeypot — vyplněné pole = bot, tiše zahodit
  def answer
    quiz = Quiz.find_by(name: params[:name])
    return head :not_found unless quiz
    return render json: { ok: true } if params[:website].present?  # honeypot

    question_no = params[:question_no].to_i
    unless quiz.question_open?(question_no)
      return render json: { ok: false, error: 'Kvíz (nebo tento den) není otevřený.' }, status: :forbidden
    end

    friend = find_or_create_friend
    return render json: { ok: false, error: 'Chybí přezdívka.' }, status: :unprocessable_entity unless friend

    if QuizAnswer.where(friend_id: friend.id).where('created_at > ?', 1.minute.ago).count >= THROTTLE_PER_MINUTE
      return render json: { ok: false, error: 'Zpomal trochu.' }, status: :too_many_requests
    end

    ans = QuizAnswer.find_or_initialize_by(quiz: quiz, friend: friend, question_no: question_no)
    ans.answer = params[:answer].to_s
    ans.data = params[:data].permit!.to_h if params[:data].present? && params[:data].respond_to?(:permit)
    ans.save!
    render json: { ok: true, uuid: friend.uuid, correct: correct?(quiz, question_no, ans.answer) }
  end

  ##
  # GET /quiz/:name — stránka kvízu/anketky s formulářem
  #
  # Jednoduchá obecná stránka: nick + jedno textové pole (question_no 1).
  # Otázku bere z quiz.data['question'], je-li.
  #
  # *Provides* @quiz
  def show
    @quiz = Quiz.find_by(name: params[:name])
    return head :not_found unless @quiz
  end

  ##
  # GET /quiz/:name/vysledky — pseudo-výsledkovka
  #
  # *Provides*
  # @quiz::
  # @rows:: pole hashů {friend:, count:, correct:, last:} — u kvízu se
  #         správnými odpověďmi řadí podle počtu správných
  def vysledky
    @quiz = Quiz.find_by(name: params[:name])
    return head :not_found unless @quiz
    answers = @quiz.quiz_answers.includes(friend: :user)
    @rows = answers.group_by(&:friend).map do |friend, list|
      correct = list.count { |a| correct?(@quiz, a.question_no, a.answer) == true }
      { friend: friend, count: list.size, correct: correct,
        last: list.map(&:updated_at).max }
    end.sort_by { |r| [-r[:correct], -r[:count]] }
  end

  private

  ##
  # Přihlášený → kanonický friend; jinak dle uuid; jinak lazy z nick.
  def find_or_create_friend
    if current_user
      return current_user.friend || Friend.create!(user: current_user, nick: current_user.full_name)
    end
    if params[:uuid].present?
      friend = Friend.find_by(uuid: params[:uuid].to_s)
      return friend if friend
    end
    return nil if params[:nick].to_s.strip.empty?
    f = Friend.new(nick: params[:nick])
    f.save ? f : nil
  end

  ##
  # true/false podle quiz.data['correct'][question_no], nil když kvíz
  # správné odpovědi nedefinuje (poll)
  def correct?(quiz, question_no, answer)
    correct = quiz.data && quiz.data['correct']
    return nil unless correct
    expected = correct[question_no.to_s]
    return nil if expected.nil?
    expected.to_s.strip.casecmp?(answer.to_s.strip)
  end
end

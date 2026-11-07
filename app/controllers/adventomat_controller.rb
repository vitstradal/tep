require 'adventomat'

##
# Adventomat — JSON API pro kalendář ve wiki stránce webu, tunel zadání z piki,
# odpovědi, debug a kontrola dnů pro orgy (viz docs/superpowers/specs/2026-11-07-adventomat-design.md).
class AdventomatController < ApplicationController
  include FriendLookup
  authorize_resource class: false

  THROTTLE_PER_MINUTE = 30

  before_action :_load_game
  before_action :_no_store, except: %i[obrazek kontrola]

  # GET /quiz/advent-<rok>/kalendar
  def kalendar
    now = _now
    solved = _solved_days
    render json: {
      year: @game.year, title: @game.title, now: now.iso8601,
      next_open_at: @game.next_open_at(now)&.iso8601, closes_at: @game.closes_at.iso8601,
      closed: now > @game.closes_at, min_table: @game.min_table,
      days: @game.order.map { |n| _day_json(n, now, solved) },
      reward: _all_solved?(solved), table: _table,
      friend: (f = current_friend) && { nick: f.nick, uuid: f.uuid },
      org: !!current_user&.org?, debug: _debug && { now: _debug_now.iso8601 },
    }
  end

  # GET /quiz/advent-<rok>/den/:den
  def den
    no = _day_no
    return _locked(no) unless no && @game.days[no] && @game.open?(no, _now)
    day = @game.days[no]
    render json: { no: no, label: day.label, html: @game.day_html(no) }
  end

  # GET /quiz/advent-<rok>/obrazek/*soubor
  def obrazek
    name = params[:soubor].to_s
    now = _now
    open_days = @game.days.keys.select { |n| @game.open?(n, now) }
    return head :forbidden unless @game.image_allowed?(name, open_days, reward: _all_solved?(_solved_days))
    data = @game.image(name)
    return head :not_found if data.nil?
    send_data data, type: Rack::Mime.mime_type(File.extname(name), 'application/octet-stream'), disposition: 'inline'
  end

  # GET /quiz/advent-<rok>/odmena
  def odmena
    return render(json: { ok: false }, status: :forbidden) unless @game.reward && _all_solved?(_solved_days)
    render json: { ok: true, html: @game.reward_html }
  end

  # GET /quiz/advent-<rok>/moje
  def moje
    f = current_friend
    render json: { solved: _solved_days, nick: f&.nick }
  end

  # POST /quiz/advent-<rok>/answer
  def answer
    return render(json: { ok: true }) if params[:website].present?
    no = _day_no
    return _locked(no) unless no && @game.days[no] && @game.open?(no, _now)
    correct = @game.check_answer(no, params[:answer])
    if correct == :not_number
      return render json: { ok: false, error: 'Napiš jen číslo.' }, status: :unprocessable_entity
    end
    return _debug_answer(no, correct) if _debug

    friend = find_or_create_friend
    return render json: { ok: false, error: 'Chybí přezdívka.' }, status: :unprocessable_entity unless friend
    if QuizAnswer.where(friend_id: friend.id).where('created_at > ?', 1.minute.ago).count >= THROTTLE_PER_MINUTE
      return render json: { ok: false, error: 'Zpomal trochu.' }, status: :too_many_requests
    end
    ans = QuizAnswer.find_or_initialize_by(quiz: _quiz, friend: friend, question_no: no)
    unless _solved?(ans)
      ans.answer = params[:answer].to_s.gsub(/\s+/, '')
      ans.data = { 'solved_at' => Time.current.iso8601 } if correct
      ans.save!
    end
    render json: { ok: true, uuid: friend.uuid, correct: correct, solved: _solved?(ans) }
  end

  # POST /quiz/advent-<rok>/debug — org: off=1 vypne, jinak now=2026-12-24T03:14
  def debug
    if params[:off].present?
      session.delete(:adventomat_debug)
      return render json: { ok: true, debug: nil }
    end
    now = Adventomat::ZONE.parse(params[:now].to_s) rescue nil
    return render json: { ok: false, error: 'Nečitelný čas.' }, status: :unprocessable_entity if now.nil?
    state = session[:adventomat_debug] || {}
    session[:adventomat_debug] = state.merge('now' => now.iso8601, 'solved' => state['solved'] || {})
    render json: { ok: true, debug: { now: now.iso8601 } }
  end

  # GET /quiz/advent-<rok>/kontrola
  def kontrola
    @order = %i[error warn]
    @issues = @game.issues.sort_by { |i| [@order.index(i[:level]), i[:day].to_s.rjust(3, '0')] }
    @breadcrumb = [[{ name: "Kontrola: #{@game.title}", url: request.path }]]
  end

  private

  def _load_game
    @game = Adventomat.load(Adventomat.year_of(params[:name]))
    return if @game
    respond_to do |format|
      format.html { head :not_found }
      format.any { render json: { ok: false, error: 'Adventomat neexistuje.' }, status: :not_found }
    end
  end

  def _no_store
    response.headers['Cache-Control'] = 'no-store'
  end

  def _quiz
    @quiz ||= Quiz.find_or_create_by!(name: @game.quiz_name) { |q| q.quiz_type = 'advent' }
  end

  def _day_no
    label = params[:den].presence || params[:question_no].to_s
    return Adventomat::BONUS if label == 'bonus'
    n = label.to_i
    (1..Adventomat::BONUS).cover?(n) ? n : nil
  end

  def _locked(no)
    opens = no && @game.open_at(no)
    render json: { ok: false, error: 'Okénko ještě není otevřené.', opens_at: opens&.iso8601 }, status: :forbidden
  end

  def _day_json(no, now, solved)
    state = if solved.include?(no) then 'solved'
            elsif @game.open?(no, now) then @game.days[no] ? 'open' : 'missing'
            else 'locked'
            end
    { no: no, label: no == Adventomat::BONUS ? 'bonus' : no.to_s, state: state, opens_at: @game.open_at(no).iso8601 }
  end

  def _solved?(ans)
    ans.persisted? && ans.data.is_a?(Hash) && ans.data['solved_at'].present?
  end

  def _solved_days
    return _debug.dig('solved', @game.year.to_s).to_a if _debug
    friend = current_friend
    return [] unless friend
    quiz = Quiz.find_by(name: @game.quiz_name)
    return [] unless quiz
    QuizAnswer.where(quiz: quiz, friend: friend).select { |a| _solved?(a) }.map(&:question_no).sort
  end

  def _all_solved?(solved)
    need = @game.days.keys
    need.any? && (need - solved).empty?
  end

  def _table
    quiz = Quiz.find_by(name: @game.quiz_name)
    return [] unless quiz
    close = @game.closes_at
    rows = quiz.quiz_answers.includes(friend: :user).group_by(&:friend).filter_map do |friend, list|
      count = list.count { |a| _solved?(a) && Time.zone.parse(a.data['solved_at']) <= close }
      next if count < @game.min_table
      { nick: friend.display_nick, count: count, verified: friend.status == 'verified', disc: friend.discriminator }
    end
    dup = rows.group_by { |r| r[:nick] }.select { |_, v| v.size > 1 }.keys
    rows.each { |r| r[:nick] = "#{r[:nick]} ·#{r[:disc]}" if dup.include?(r[:nick]) }
    rows.each { |r| r.delete(:disc) }
    rows.sort_by { |r| [-r[:count], r[:nick].downcase] }
  end

  def _debug
    return nil unless current_user&.org?
    session[:adventomat_debug]
  end

  def _debug_now
    Time.zone.parse(_debug['now'].to_s)
  end

  def _now
    _debug ? _debug_now : Time.current
  end

  def _debug_answer(no, correct)
    if correct
      solved = _debug['solved'] || {}
      list = (solved[@game.year.to_s].to_a + [no]).uniq.sort
      session[:adventomat_debug] = _debug.merge('solved' => solved.merge(@game.year.to_s => list))
    end
    render json: { ok: true, correct: correct, solved: _solved_days.include?(no), debug: true }
  end
end

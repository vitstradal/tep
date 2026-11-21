##
# Přítel Pikomatu — kvízová identita a její napojení na účet
# (viz navrh-kvizy-a-pratele.md).
#
# JSON API pro hlavičkový widget a kvízový JS. Anonymní identita se
# prokazuje uuid (drží ho prohlížeč v localStorage); přihlášený uživatel
# má vždy přednost — dostává svého kanonického frienda.
require 'friend_captcha'

class FriendController < ApplicationController
  MAILS_PER_DAY = 200
  MAIL_PAUSE = 1.day

  authorize_resource :class => false

  ##
  # POST /friend/hello — založ/aktualizuj anonymního frienda
  #
  # *Params*
  # uuid:: existující friend (volitelný)
  # nick:: přezdívka
  def hello
    friend = params[:uuid].present? ? Friend.find_by(uuid: params[:uuid]) : nil
    friend ||= Friend.new
    friend.nick = params[:nick] if params[:nick].present? || friend.new_record?
    friend.last_seen_at = Time.now
    if friend.save
      render json: friend_json(friend)
    else
      render json: { errors: friend.errors.full_messages }, status: :unprocessable_entity
    end
  end

  ##
  # GET /friend/status — stav pro hlavičkový widget
  #
  # *Params*
  # uuid:: friend z localStorage (přihlášenému slouží jen k detekci merge)
  def status
    if current_user
      friend = canonical_friend(current_user)
      merge_candidate = params[:uuid].present? && params[:uuid] != friend.uuid &&
                        Friend.where(uuid: params[:uuid], user_id: nil).exists?
      render json: friend_json(friend).merge(signed_in: true, org: current_user.org?,
                                             merge_candidate: merge_candidate)
    else
      friend = Friend.find_by(uuid: params[:uuid].to_s)
      if friend
        friend.update_column(:last_seen_at, Time.now)
        render json: friend_json(friend)
      else
        render json: { status: 'unknown' }
      end
    end
  end

  ##
  # POST /friend/claim — přihlášený si přivlastní anonymního frienda
  # (adopce, nebo merge odpovědí do kanonického)
  #
  # *Params*
  # uuid:: anonymní friend z localStorage
  def claim
    return redirect_to new_user_session_path unless current_user
    other = Friend.find_by(uuid: params[:uuid].to_s, user_id: nil)
    mine = current_user.friend
    if other.nil?
      friend = canonical_friend(current_user)
    elsif mine.nil?
      other.update!(user: current_user)
      friend = other
    else
      merge_friends(mine, other)
      friend = mine
    end
    render json: friend_json(friend)
  end

  ##
  # GET /pritel — registrační formulář přítele Pikomatu
  def register_form
    @nick = params[:nick]
    @captcha = FriendCaptcha.new
    session[:friend_captcha] = @captcha.state
  end

  ##
  # POST /friend/register — zaregistruj přítele (jen email)
  #
  # Neprozrazuje, zda email existuje (anti-enumeration): odpověď je
  # vždy stejná, jen se pošle jiný mail. Proti botům: honeypot `website`,
  # sčítací captcha, nejvýš jeden mail na adresu za den a denní strop mailů.
  #
  # *Params*
  # uuid:: friend z localStorage (volitelný, jinak se založí z nick)
  # nick:: přezdívka pro lazy založení
  # email:: adresa pro registraci
  # captcha:: součet z formuláře
  # website:: honeypot
  def register
    done = lambda do
      add_success 'Koukni do mailu a dokonči registraci (link platí 7 dní).'
      redirect_to root_path
    end
    captcha = session.delete(:friend_captcha)
    return done.call if params[:website].present?
    unless FriendCaptcha.valid?(captcha, params[:captcha])
      add_alert 'Součet nesedí (nebo formulář ležel moc dlouho). Zkus to prosím znovu.'
      return redirect_to friend_register_form_path(nick: params[:nick])
    end
    if _mails_today >= MAILS_PER_DAY
      add_alert 'Registrací je dnes moc, zkus to prosím zítra.'
      return redirect_to root_path
    end

    friend = Friend.find_by(uuid: params[:uuid].to_s)
    email = params[:email].to_s.downcase.strip
    unless email =~ Devise.email_regexp
      add_alert 'Zadej platnou emailovou adresu.'
      return redirect_to friend_register_form_path
    end
    if friend.nil?
      friend = Friend.new(nick: params[:nick])
      unless friend.save
        add_alert 'Zadej přezdívku.'
        return redirect_to friend_register_form_path
      end
    end

    existing = User.find_by_email(email)
    if existing
      # účet už je — pošli návod na přihlášení/reset, web mlčí
      existing.send_reset_password_instructions unless _mailed_recently?(existing)
    else
      user = User.new(email: email, password: SecureRandom.hex(16))
      user.skip_confirmation_notification!
      user.save!
      friend.update!(user: user) if friend.user_id.nil?
      user.send_confirmation_instructions
    end
    done.call
  end

  ##
  # GET /friend/finish/:token — dokončení registrace: potvrzení mailu + heslo
  def finish
    @user = User.find_by(confirmation_token: params[:token])
    if @user.nil? || @user.confirmed_at
      add_alert 'Odkaz je neplatný nebo už použitý.'
      return redirect_to root_path
    end
    if @user.send(:confirmation_period_expired?)  # v Devise protected
      add_alert 'Odkaz už vypršel — nech si poslat nový.'
      return redirect_to root_path
    end
    @token = params[:token]
  end

  ##
  # POST /friend/finish/:token — nastav heslo, potvrď, přihlas
  def do_finish
    user = User.find_by(confirmation_token: params[:token])
    if user.nil? || user.confirmed_at || user.send(:confirmation_period_expired?)
      add_alert 'Odkaz je neplatný nebo už použitý.'
      return redirect_to root_path
    end
    user.password = params[:password]
    user.password_confirmation = params[:password_confirmation]
    if user.save
      user.confirm
      sign_in(user)
      add_success 'Registrace dokončena, vítej!'
      redirect_to root_path
    else
      add_alert user.errors.full_messages.join(', ')
      redirect_to friend_finish_path(token: params[:token])
    end
  end

  ##
  # POST /friend/resend — znovu pošli dokončovací link
  #
  # *Params*
  # uuid:: friend z localStorage
  def resend
    friend = Friend.find_by(uuid: params[:uuid].to_s)
    user = friend && friend.user
    if user && user.confirmed_at.nil? && !(user.confirmation_sent_at && user.confirmation_sent_at > 1.hour.ago)
      user.send_confirmation_instructions
      add_success 'Dokončovací mail poslán znovu.'
    end
    redirect_to root_path
  end

  private

  def _mailed_recently?(user)
    [user.reset_password_sent_at, user.confirmation_sent_at].compact.any? { |t| t > MAIL_PAUSE.ago }
  end

  def _mails_today
    User.where('confirmation_sent_at > :t OR reset_password_sent_at > :t', t: 1.day.ago).count
  end

  ##
  # Kanonický friend přihlášeného; založí ho, pokud chybí.
  def canonical_friend(user)
    user.friend || Friend.create!(user: user, nick: user.full_name)
  end

  ##
  # Přepoj odpovědi z other na mine (kolize vyhrává mine, jen vyřešený den adventomatu vyhraje vždy) a other smaž.
  def merge_friends(mine, other)
    Friend.transaction do
      other.quiz_answers.each do |ans|
        have = QuizAnswer.find_by(quiz_id: ans.quiz_id, question_no: ans.question_no, friend_id: mine.id)
        next if have && !(_solved?(ans) && !_solved?(have))
        have&.destroy
        ans.update_columns(friend_id: mine.id)
      end
      other.reload.destroy
    end
  end

  # vyřešený den adventomatu (data.solved_at)
  def _solved?(ans)
    ans.data.is_a?(Hash) && ans.data['solved_at'].present?
  end

  def friend_json(friend)
    { uuid: friend.uuid, nick: friend.nick, status: friend.status }
  end
end

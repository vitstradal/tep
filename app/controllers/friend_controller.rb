##
# Přítel Pikomatu — kvízová identita a její napojení na účet
# (viz navrh-kvizy-a-pratele.md).
#
# JSON API pro hlavičkový widget a kvízový JS. Anonymní identita se
# prokazuje uuid (drží ho prohlížeč v localStorage); přihlášený uživatel
# má vždy přednost — dostává svého kanonického frienda.
class FriendController < ApplicationController
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
      render json: friend_json(friend).merge(signed_in: true, merge_candidate: merge_candidate)
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

  private

  ##
  # Kanonický friend přihlášeného; založí ho, pokud chybí.
  def canonical_friend(user)
    user.friend || Friend.create!(user: user, nick: user.full_name)
  end

  ##
  # Přepoj odpovědi z other na mine (kolize vyhrává mine) a other smaž.
  def merge_friends(mine, other)
    Friend.transaction do
      other.quiz_answers.each do |ans|
        next if QuizAnswer.where(quiz_id: ans.quiz_id, question_no: ans.question_no,
                                 friend_id: mine.id).exists?
        ans.update_columns(friend_id: mine.id)
      end
      other.reload.destroy
    end
  end

  def friend_json(friend)
    { uuid: friend.uuid, nick: friend.nick, status: friend.status }
  end
end

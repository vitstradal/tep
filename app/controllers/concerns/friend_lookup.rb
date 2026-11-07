##
# Kvízová identita aktuálního požadavku (viz navrh-kvizy-a-pratele.md).
module FriendLookup
  extend ActiveSupport::Concern

  private

  ##
  # Přihlášený → kanonický friend; jinak dle uuid; jinak lazy z nick.
  # Výjimka: `anon=1` (přihlášený si v anketě změnil jméno a chce odpovídat jako anonym) přeskočí
  # účet a použije anonymní identitu podle uuid/nick.
  def find_or_create_friend
    if current_user && params[:anon].blank?
      return current_user.friend || Friend.create!(user: current_user, nick: current_user.full_name)
    end
    # uuid = bearer token anonymní identity (kdo ho zná, smí pod ním odpovídat — přijatelné pro
    # sranda kvízy). VÝJIMKA: friend napojený na skutečný účet (`user_id`) je chráněný — smí pod
    # ním postovat jen ten přihlášený uživatel, jinak odmítni (jeden uživatel nesmí postovat za
    # jiného ani při znalosti jeho uuid).
    if params[:uuid].present?
      friend = Friend.find_by(uuid: params[:uuid].to_s)
      if friend
        return nil if friend.user_id && (current_user.nil? || friend.user_id != current_user.id)
        return friend
      end
    end
    return nil if params[:nick].to_s.strip.empty?
    f = Friend.new(nick: params[:nick])
    f.save ? f : nil
  end

  # jako find_or_create_friend, ale nic nezakládá
  def current_friend
    return current_user.friend if current_user
    friend = params[:uuid].present? && Friend.find_by(uuid: params[:uuid].to_s)
    friend && friend.user_id.nil? ? friend : nil
  end
end

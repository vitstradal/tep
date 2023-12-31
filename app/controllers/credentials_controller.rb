##
# Controller pro příhlášení oauth2
class CredentialsController <  ApplicationController
  before_action :doorkeeper_authorize!
  respond_to    :json

  ##
  #   GET /me.json
  #
  # vratí json s informacemi přihlášeným uživatelem, pokud je přihlášen přes oauth2, souvisi s `doorkeeper`
  def me
    user = _current_resource_owner
    return render json: {} if user.nil?
    groups = []
    groups.push 'org' if user.org?
    groups.push 'admin' if user.admin?

    Rails::logger.fatal("groups:" + groups.join(' '))

    render json: { internalid:  user.id,
                   id:          user.email,
                   identifier:  user.email,
                   groups:      groups,
                   email:       user.email,
                   name:        user.email,
                   username:    user.email,
                   login:       user.email,
                   firstName:   user.name,
                   lastName:    user.last_name,
                   displayName: user.full_name
                  }
  end


# toto je pro klep, autorizace pomoci gitlabu
# coz je oauth, akorat ze na /me vyzaduje prestou strukturu
# (nestaci poloziky pridat do stavajiciho /me, nechutna mu kdyz tam je neco navic)
# type GitLabUser struct {
#         Id       int64  `json:"id"`
#         Username string `json:"username"`
#         Login    string `json:"login"`
#         Email    string `json:"email"`
#         Name     string `json:"name"`
#}
  def me_gitlab
    user = _current_resource_owner
    return render json: {} if user.nil?
    groups = user.is_org? ? 'org' :  ''
    render json: {
                   id:          user.id,
                   username:    user.email,
                   login:       user.email,
                   email:       user.email,
                   name:        user.name,
                  }
  end

  private

  # Find the user that owns the access token
  def _current_resource_owner
    User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
end

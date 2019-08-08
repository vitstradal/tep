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
    render json: { internalid: user.id, id: user.email  }
  end

  private

  # Find the user that owns the access token
  def _current_resource_owner
    User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
end

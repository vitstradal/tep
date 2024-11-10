class SosnaController < ApplicationController

  authorize_resource

  before_action do
    load_config
  end
end

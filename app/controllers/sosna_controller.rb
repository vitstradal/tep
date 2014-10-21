class SosnaController < ApplicationController

  authorize_resource

  before_filter do
    load_config
  end
end

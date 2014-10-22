class Sosna::AesopController < ApplicationController
  include ApplicationHelper
  def index
    load_config
    render text: "pikomat-#{@annual}-#{@round}.txt" 
  end
end

class PiaController < ApplicationController
  def index
    render
  end
  def hello
    render
  end
  def users
    @users = User.all
  end
end

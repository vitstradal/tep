class SosnaProblemController < ApplicationController

  def index
      @problems = SosnaProblem.all
  end

  def show
    @problem = SosnaProblem.find_or_new(params[:id])
    logger.fatal "id #{@problem.id}"
  end

  def update
    p = params[:sosna_problem]
    if p[:id]
      problem = SosnaProblem.find p[:id]
      problem.update_attributes p
    else
      problem = SosnaProblem.create p
    end
    redirect_to :action=> :show, :id => problem.id
  end
end

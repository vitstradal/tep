
require 'json'


class InformController < ApplicationController
  authorize_resource
  include ApplicationHelper

  def index
    @form = params[:form]
    @informs = Inform.where({ form: @form})
    @forms = Inform.select(:form).group(:form)
    hkeys = {}
    @informs.each do |inform|
      inform.jdata.each do |k,v| 
        hkeys[k] = 1 
      end
    end
    @keys = hkeys.keys.sort
  end

  def tnx
    @tnx = flash[:tnx]
    @tnx2 = flash[:tnx2]
  end

  def add
    data = {}
    params.each do |k,v|
      next if k == 'controller' || k == 'action' || k == 'authenticity_token'
      data[k] = v
    end
    form = data.delete('form') || 'unk'
    redir = data.delete('redir')

    flash[:tnx] = data.delete('tnx') || "Děkujeme."
    flash[:tnx2] = data.delete('tnx2')

    datastr = JSON.dump(data);

    Inform.create(form:  form, data: datastr, user_agent: request.env['HTTP_USER_AGENT'] || 'unknown');

    redirect_to :inform_tnx
  end

  def del
    inform = Inform.find(params['id'])
    form = inform.form
    inform.delete
    redirect_to inform_index_url(form)
  end

end

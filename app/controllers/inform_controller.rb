
require 'json'

class InformController < ApplicationController
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

  def add
    data = {}
    params.each do |k,v|
      next if k == 'controller' || k == 'action' || k == 'authenticity_token'
      data[k] = v
    end
    form = data.delete('form') || 'unk'
    redir = data.delete('redir')
    datastr = JSON.dump(data);j
    Inform.create(form:  form, data: datastr);
    render text: "tnx(#{form}:#{data})"
  end

  def del
    inform = Inform.find(params['id'])
    form = inform.form
    inform.delete
    redirect_to inform_index_url(form)
  end

end

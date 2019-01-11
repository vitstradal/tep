
require 'json'


class InformController < ApplicationController
  authorize_resource
  include ApplicationHelper

  def index
    @form = params[:form]
    @informs = Inform.where({ form: @form})
    @forms = Inform.select(:form).group(:form)
    hkeys = {}
    order = nil
    @informs.each do |inform|
      inform.jdata.each do |k,v| 
        if k == 'inform_order'
          order = v
          next
        end
        hkeys[k] = 1 
      end
    end
    if ! order.nil?
      @keys = order.split(':')
      @keys.push('thanks_email_sent')
    else
      @keys = hkeys.keys.sort
    end
    @wide_display = true
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

    ordered_data = _order_data(data)
    _send_thanks_email(data, ordered_data)
    _send_bonz_email(data, ordered_data, form)

    datastr = JSON.dump(data);

    Inform.create(form:  form, data: datastr, user_agent: request.env['HTTP_USER_AGENT'] || 'unknown');

    redirect_to :inform_tnx
  end

  def _send_bonz_email(data, ordered_data, form)
    # bonzovaci email (vlastnikovi ankety)
    bonz_email = sign_verified(data.delete('bonz_email'), 'giwi-sign')
    #log "senging bonz_email '#{bonz_email}'"
    if ! bonz_email.nil?
      Tep::Mailer.inform_bonz_email(bonz_email, 'PIKOMAT: Inform submit notification', data, ordered_data, form).deliver_later
    end
  end

  def _send_thanks_email(data, ordered_data)
    # dekovaci email (tomu kdo to vyplnil)
    thanks_email = data['email'] || data['Email'] || data['E-mail'] || ''
    thanks_email_text = sign_verified(data.delete('thanks_email_text'), 'giwi-sign')
    thanks_email_subj = sign_verified(data.delete('thanks_email_subj'), 'giwi-sign')
    #log "thanks_email='#{thanks_email}'"
    #log "thanks_email_text='#{thanks_email_text}'"
    #log "thanks_email_subj='#{thanks_email_subj}'"
    ordered_data = _order_data(data)
    data['thanks_email_sent'] = false
    if (!thanks_email.empty?) && email_valid_mx_record?(thanks_email)
      thanks_email_text
      data['thanks_email_sent'] = true
      Tep::Mailer.inform_thanks_email(thanks_email, thanks_email_subj, thanks_email_text, ordered_data).deliver_later
    end
  end

  def _order_data(data)
    ordered_data = []
    used_keys = {}
    order = data['inform_order'] || ''
    order.split(':').each do |key|
      next if key.nil? || key == ''
      ordered_data.push [ key, data[key] ]
      used_keys[key] = true
    end
#    data.keys.sort.each do |key|
#      next if ! used_keys[key].nil?
#      ordered_data.push [ key, data[key] ]
#    end
    return ordered_data
  end

  def del
    inform = Inform.find(params['id'])
    form = inform.form
    inform.delete
    redirect_to inform_index_url(form)
  end

end

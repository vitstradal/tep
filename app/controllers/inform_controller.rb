
require 'json'


##
# Controller pro formuláře, ankety a přihlášky ve wiki.
# Ve spolupráci s wiky makry `{{inf_*}}`.
# see: https://pikomat.mff.cuni.cz/tepmac/inform
#

class InformController < ApplicationController
  authorize_resource
  include ApplicationHelper

  ##
  #   GET  /inform/index/(:form)
  #
  # *Params*
  # form:: id formuláře, např +tabor2035+
  # style:: způsob zobrazeni Informů:
  #         tab:: jedna velká tabulka
  #         list:: položky jako odrážky
  #         list2:: tabulky po položkách
  #
  # *Provides*
  # @informs::       vsechny zaslane data (Inform) pro dany formular dany `form`
  # @form::          id form (`form`)
  # @forms::         všechny ankety
  # @keys::          sloupce formuráře v preferovaném pořadí
  # @wide_display::  is set to `true`
  #
  def index
    @form = params[:form]
    @informs = Inform.where({ form: @form})
    @forms = Inform.select(:form).group(:form)
    hkeys = {}
    order = nil
    @informs.each do |inform|
      # Přijmení => Příjemní
      if inform.jdata.has_key? 'Přijmení' and ! inform.jdata.has_key? 'Příjmení'
        inform.jdata['Příjmení'] = inform.jdata.delete('Přijmení')
      end
      inform.jdata.each do |k,v| 
        if k == 'inform_order'
          order = v
          next
        end
        hkeys[k] = 1 
      end
    end

    if ! order.nil?
      # Přijmení -> Příjmení
      @keys = order.split(':').map{|k|k=='Přijmení'?'Příjmení':k}
      @keys.push('thanks_email_sent')
      hkeys.keys.sort.each do |key|
        @keys.push(key) if ! @keys.include? key
      end
    else
      @keys = hkeys.keys.sort
    end

    @wide_display = true
  end

  ##
  #  GET  /inform/tnx
  #
  # sem se redirectne `POST /infrom/add`
  #
  # *Flash*
  # tnx, tnx2:: text s poděkováním
  #
  # *Profides*
  # @tnx, @tnx2:: text s poděkováním
  # 
  def tnx
    @tnx = flash[:tnx]
    @tnx2 = flash[:tnx2]
  end

  ##
  #  POST  /inform/add
  #
  # *Params*
  # from: id formuláře
  # redir:: kam se ma po zapsání přesměrovat 
  # *::  ostatní parametry se přidají do Inform.data (jako json)
  # bonz_email:: tam se bonzovaci email, hodnota je podepsaná a zakodovaná pomocí `sign_generate(email, 'gigi-gen')`, viz makro {{inf_bonz_email}}
  # email, E-mail, Email:: tam se pošle děkovný mail, hodnota je podepsaná a zakodovaná pomocí `sign_generate`
  #
  # Flash
  # tnx, tnx2: hidden položky formuláře +tnx+, +tnx2+ viz macro `{{inf_thanks}}`
  #
  # Redirects to `inform_tnx`
  def add
    data = {}
    params.each do |k,v|
      next if k == 'controller' || k == 'action' || k == 'authenticity_token'
      data[k] = v
    end
    form = sign_verified(data.delete('form'), 'giwi-sign')
    redir = data.delete('redir')

    flash[:tnx] = data.delete('tnx') || "Děkujeme."
    flash[:tnx2] = data.delete('tnx2')

    return redirect_to :inform_tnx if form.nil?

    ordered_data = _order_data(data)
    _send_thanks_email(data, ordered_data)
    _send_bonz_email(data, ordered_data, form)

    datastr = JSON.dump(data);

    Inform.create(form:  form, data: datastr, user_agent: request.env['HTTP_USER_AGENT'] || 'unknown');

    redirect_to :inform_tnx
  end

  ##
  #  POST /inform/del
  #
  # *Params* 
  # id:: id Infrom (jeden řádek)
  #
  # Redirects to `inform_index_url(form)`
  def del
    inform = Inform.find(params['id'])
    form = inform.form
    inform.delete
    redirect_to inform_index_url(form)
  end

  ##
  #  POST /inform/delform
  #
  # *Params* 
  # from:: Infrom (jeden řádek)
  #
  # Redirects to `inform_index_url(form)`
  def delform
    form = params['form']
    sure = params['sure']

    if sure.nil? or form.nil?
      add_alert "infrom #{form} nesmazán"
      return redirect_to inform_index_url(@form)
    end

    Inform.where(form: form).destroy_all
    add_success "infrom #{form} smazán"
    redirect_to inform_index_url()
  end

  private
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


end

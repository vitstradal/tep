class Tep::Mailer < Devise::Mailer
  def first_login_instructions(record, token, opts={})
    @token = token
    devise_mail(record, :first_login_instructions)
  end

  def inform_bonz_email(to, subj, data, ordered_data, form)
    @ordered_data = ordered_data
    @data = data
    @form = form
    mail(to: to, from: 'tep@pikomat.mff.cuni.cz', subject: subj)
  end

  def inform_thanks_email(to, subj, text, ordered_data)
    @ordered_data = ordered_data
    @text = text || 'Děkujeme za vyplnění formuláře'
    subj ||= "PIKOMAT: Vyplnění formuláře"
    mail(to: to, from: 'tep@pikomat.mff.cuni.cz', subject: subj)
  end

  def error(data)
    errid = data[:errid]
    @data = data.deep_stringify_keys
    mail(to: 'vitas@matfyz.cz', from: 'tep@pikomat.mff.cuni.cz', subject: "Tep Error #{errid}")
  end
end

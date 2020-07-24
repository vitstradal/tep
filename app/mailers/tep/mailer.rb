##
# Třída na rozesílání mailů, templaty pro maily jsou v `app/views/tep/mailer/`
class Tep::Mailer < Devise::Mailer
  helper ApplicationHelper
  ##
  # *Tempate* app/views/tep/mailer/first_login_instructions.html.erb
  #
  # *Params*
  # record:: 
  # token:: token
  # opts:: 
  def first_login_instructions(record, token, opts={})
    @token = token
    devise_mail(record, :first_login_instructions)
  end

  ##
  #
  # *Tempate* app/views/tep/mailer/inform_bonz_email.html.erb
  #
  # *Params*
  # to:: to
  # subj:: subject
  # data::
  # ordered_data::
  # form::
  def inform_bonz_email(to, subj, data, ordered_data, form)
    @ordered_data = ordered_data
    @data = data
    @form = form
    mail(to: to, from: 'tep@pikomat.mff.cuni.cz', subject: subj)
  end

  ##
  # *Tempate* app/views/tep/mailer/inform_thanks_email.html.erb
  #
  # *Params*
  # to, subj, text:: email, subject, a text poděkování
  # ordered_data:: pole položek `[[key1, value2], [k2,v2], ...]`
  def inform_thanks_email(to, subj, text, ordered_data)
    @ordered_data = ordered_data
    @text = text || 'Děkujeme za vyplnění formuláře'
    subj ||= "PIKOMAT: Vyplnění formuláře"
    mail(to: to, from: 'tep@pikomat.mff.cuni.cz', subject: subj)
  end
  ##
  # *Tempate* app/views/tep/mailer/wiki_edit_modify.html.erb
  #
  # *Params*
  # to, wiki, path, who
  def wiki_edit_modify(to, wiki, path, who, url, url_diff, diff_data)
    @wiki = wiki
    @path = path
    @who = who
    @url = url
    @url_diff = url_diff
    @diff_data = diff_data

    subj = "PIKOMAT: změna #{@wiki}/#{@path}"
    mail(to: to, from: 'tep@pikomat.mff.cuni.cz', subject: subj)
  end

  ##
  # pošle mail s informacemi o chybě, na ehm `vitas@matfyz.cz`
  #
  # *Tempate* app/views/tep/mailer/error.html.erb
  #
  # *Params*
  # data:: hash, jeho obsah bude poslan v mailu 
  def error(data)
    errid = data[:errid]
    @data = data.deep_stringify_keys
    mail(to: 'vitas@matfyz.cz', from: 'tep@pikomat.mff.cuni.cz', subject: "Tep Error #{errid}")
  end

  ##
  # *Tempate* app/views/tep/mailer/solution-notification.html.erb

  #
  # *Params*
  # user:: user
  def solution_notification(email , url, annual, round)
    @email = email
    @round = round
    @annual = annual
    @url = url
    mail(to: email, from: 'tep@pikomat.mff.cuni.cz', subject: "Pikomat: vzorová řešení")
  end
end

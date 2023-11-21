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
  def first_login_instructions(record, token, is_bonus, opts={})
    @token = token
    @is_bonus = is_bonus
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
  #
  # *Tempate* app/views/tep/mailer/event_bonz_email.html.erb
  #
  # *Params*
  # to:: to
  # subj:: subject
  # event_participant::
  # is_new::

  def event_bonz_org(to, subj, event_participant, is_new)
    @event = event_participant.event
    @event_participant = event_participant
    @is_new = is_new
    
    @num_p_yes = @event.num_signed("yes", false, true)
    @num_p_no = @event.num_signed("no", false, true)
    @num_p_maybe = @event.num_signed("maybe", false, true)
    @num_p_voted = @num_p_yes + @num_p_no + @num_p_maybe

    @num_o_yes = @event.num_signed("yes", true, false)
    @num_o_no = @event.num_signed("no", true, false)
    @num_o_maybe = @event.num_signed("maybe", true, false)
    @num_o_voted = @num_o_yes + @num_o_no + @num_o_maybe

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

  def event_bonz_parent(to, subj, event_participant, is_new)
    @event = event_participant.event
    @event_participant = event_participant
    @is_new = is_new
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
  # email:: user
  # subject:: user
  # html:: text
  def solution_notification(from, email, subject, html, bottom_html = nil)
    @email = email
    @html = html
    @bottom_html = bottom_html
    mail(to: email, from: from || 'tep@pikomat.mff.cuni.cz', subject: subject)
  end
end

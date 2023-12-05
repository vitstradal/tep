class Act::Mailer < Devise::Mailer
  helper ApplicationHelper

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

  def event_bonz_parent(to, subj, event_participant, is_new)
    @event = event_participant.event
    @event_participant = event_participant
    @is_new = is_new
    mail(to: to, from: 'tep@pikomat.mff.cuni.cz', subject: subj)
  end

  ##
  # *Tempate* app/views/act/mailer/first_login_instructions.html.erb
  #
  # *Params*
  # record::
  # token:: token
  # opts::
  def first_login_instructions(record, token, opts={})
    @token = token
    devise_mail(record, :first_login_instructions)
  end
end

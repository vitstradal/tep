class Tep::Mailer < Devise::Mailer
  def first_login_instructions(record, token, opts={})
    @token = token
    devise_mail(record, :first_login_instructions)
  end
  def error(data)
    @data = data
    errid = @data[:errid]
    mail(to: 'vitas@matfyz.cz', from: 'tep@pikomat.mff.cuni.cz', subject: "Tep Error #{errid}")
  end
end

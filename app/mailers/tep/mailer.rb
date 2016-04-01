class Tep::Mailer < Devise::Mailer
  def first_login_instructions(record, token, opts={})
    @token = token
    devise_mail(record, :first_login_instructions)
  end
end

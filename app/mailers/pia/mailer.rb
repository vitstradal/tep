class Pia::Mailer < Devise::Mailer
  def first_login_instructions(record, opts={})
    #devise_mail(record, :first_login_instructions, opts)
    devise_mail(record, :first_login_instructions)
  end
end

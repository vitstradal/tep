##
# OIDC klienti (Doorkeeper applications) pro služby přihlašované přes tep.
namespace :oidc do
  # Idempotentní registrace/úprava OIDC klienta. ENV:
  #   NAME=<název aplikace>       (povinné; klíč pro find_or_create)
  #   REDIRECT_URI=<callback URL> (povinné; musí přesně sedět s klientem)
  # Vypíše client_id/secret pro konfiguraci klienta.
  # Příklad (OxiCloud pod /sklepox):
  #   NAME=oxicloud REDIRECT_URI=https://pikomat.mff.cuni.cz/sklepox/api/auth/oidc/callback \
  #     rake oidc:register RAILS_ENV=production
  desc 'Zaregistruj/uprav OIDC klienta: NAME=… REDIRECT_URI=… (idempotentní)'
  task register: :environment do
    name = ENV['NAME'].to_s.strip
    redirect = ENV['REDIRECT_URI'].to_s.strip
    abort 'Chybí NAME (např. NAME=oxicloud)' if name.empty?
    abort 'Chybí REDIRECT_URI' if redirect.empty?

    app = Doorkeeper::Application.find_or_initialize_by(name: name)
    nove = app.new_record?
    app.redirect_uri = redirect
    app.scopes = 'openid profile email'
    app.confidential = true
    app.save!

    puts "oidc:register: #{app.name} (#{nove ? 'založeno' : 'upraveno'})"
    puts "  client_id     = #{app.uid}"
    puts "  client_secret = #{app.secret}"
    puts "  redirect_uri  = #{app.redirect_uri}"
    puts "  scopes        = #{app.scopes}"
  end
end

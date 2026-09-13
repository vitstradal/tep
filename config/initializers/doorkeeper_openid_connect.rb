# OIDC vrstva nad Doorkeeperem (doorkeeper-openid_connect).
#
# Pridava discovery dokument (/.well-known/openid-configuration),
# id_token a /oauth/userinfo — presne to, co potrebuje OxiCloud SSO
# (a pripadny dalsi OIDC klient). Kdo smi OAuth pouzit dal ridi
# resource_owner_authenticator v doorkeeper.rb (jen org uzivatele).
#
# Podpisovy klic: `make gen-oidc-signing-key` (soubor je v .gitignore,
# na kazdem prostredi zvlast — stejny vzor jako secret_key_base).

Doorkeeper::OpenidConnect.configure do
  # Issuer musi byt presne ta URL, pod kterou klienti tep vidi —
  # OxiCloud si z ni sklada <issuer>/.well-known/openid-configuration
  # a overuje `iss` claim v id_tokenu.
  issuer do |_resource_owner, _application|
    Rails.env.production? ? 'https://pikomat.mff.cuni.cz' : 'http://localhost:3000'
  end

  signing_key File.read(Rails.root.join('config', 'oidc_signing_key.pem'))

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |user|
    user.current_sign_in_at
  end

  reauthenticate_resource_owner do |_user, return_to|
    store_location_for :user, return_to
    sign_out :user
    redirect_to new_user_session_url
  end

  subject do |user, _application|
    user.id
  end

  claims do
    # `email_verified: true` je podminka, za ktere si OxiCloud dovoli
    # auto-link na existujici lokalni ucet se stejnym emailem
    # (OXICLOUD_OIDC_AUTO_LINK_EMAIL_MATCH). Tep emaily overuje
    # (devise :confirmable), takze to plati.
    claim :email, scope: :email do |user|
      user.email
    end
    claim :email_verified, scope: :email do |user|
      user.confirmed_at.present?
    end
    claim :name, scope: :profile do |user|
      user.full_name
    end
    claim :preferred_username, scope: :profile do |user|
      user.email
    end
  end
end

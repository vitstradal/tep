require 'test_helper'

##
# Testy archivace informů (starší než ARCHIVE_AFTER podle PRVNÍHO submitu
# vidí jen admin) a CSV exportu (style=csv, stejné sloupce jako tab).
class InformControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  def make_user(email, roles)
    u = User.new(email: email, password: 'password123', roles: roles)
    u.skip_confirmation!
    u.save!
    u
  end

  def make_inform(form, data, created_at = Time.now)
    Inform.create!(form: form, data: JSON.dump(data),
                   user_agent: 'test-agent', created_at: created_at)
  end

  setup do
    @org   = make_user('org@x.cz',   [:org])
    @admin = make_user('admin@x.cz', [:org, :admin])

    make_inform('nova',  { 'Jmeno' => 'Petr', 'Vek' => '12' })
    make_inform('stara', { 'Jmeno' => 'Karel' }, 2.years.ago)
    # post do stare ankety ji nesmi "ozivit" (rozhoduje prvni submit)
    make_inform('stara', { 'Jmeno' => 'Novacek' })
  end

  ### listing

  test "org: listing ukaze pristupne ankety a archivovane bez odkazu" do
    sign_in @org
    get :index
    assert_response :success
    assert_select "a[href=?]", "/inform/index/nova"
    assert_select "a[href=?]", "/inform/index/stara", count: 0
    assert_select 'h3', text: 'Archivované informy'
    assert_select 'li', text: 'stara'
  end

  test "admin: listing ma odkazy i na archivovane" do
    sign_in @admin
    get :index
    assert_response :success
    assert_select "a[href=?]", "/inform/index/nova"
    assert_select "a[href=?]", "/inform/index/stara"
  end

  ### primy pristup na anketu

  test "org: cerstva anketa je pristupna" do
    sign_in @org
    get :index, params: { form: 'nova' }
    assert_response :success
    assert_match 'Petr', response.body
  end

  test "org: primy pristup na archivovanou anketu je odmitnut" do
    sign_in @org
    get :index, params: { form: 'stara' }
    assert_redirected_to '/inform/index'
    assert_match 'archivovaný', Array(flash[:alerts]).join
  end

  test "org: novy submit starou anketu nezpristupni" do
    # 'stara' ma submit z dneska (viz setup), presto zustava archivovana
    sign_in @org
    get :index, params: { form: 'stara' }
    assert_redirected_to '/inform/index'
  end

  test "admin: archivovana anketa je pristupna a oznacena jako archiv" do
    sign_in @admin
    get :index, params: { form: 'stara' }
    assert_response :success
    assert_match 'Karel', response.body
    assert_select 'h1 span.label', text: /archiv/
  end

  test "admin: cerstva anketa znacku archiv nema" do
    sign_in @admin
    get :index, params: { form: 'nova' }
    assert_select 'h1 span.label', count: 0
  end

  test "anketa presne na hranici 1.5 roku je jeste pristupna" do
    make_inform('hranicni', { 'Jmeno' => 'Hugo' },
                InformController::ARCHIVE_AFTER.ago + 1.day)
    sign_in @org
    get :index, params: { form: 'hranicni' }
    assert_response :success
  end

  ### csv export

  test "csv: stahne csv se sloupci jako tab" do
    sign_in @org
    get :index, params: { form: 'nova', style: 'csv' }
    assert_response :success
    assert_match %r{^text/csv}, response.content_type
    assert_match 'inform-nova.csv', response.headers['Content-Disposition']
    body = response.body.sub("\uFEFF", '')
    rows = CSV.parse(body)
    assert_equal ['#', 'ua', 'Jmeno', 'Vek'], rows[0]
    assert_equal ['1', 'test-agent', 'Petr', '12'], rows[1]
  end

  test "csv: chybejici hodnota je pomlcka" do
    make_inform('nova', { 'Jmeno' => 'Bez Veku' })
    sign_in @org
    get :index, params: { form: 'nova', style: 'csv' }
    rows = CSV.parse(response.body.sub("\uFEFF", ''))
    assert_equal ['2', 'test-agent', 'Bez Veku', '-'], rows[2]
  end

  test "csv: org nestahne archivovanou anketu" do
    sign_in @org
    get :index, params: { form: 'stara', style: 'csv' }
    assert_redirected_to '/inform/index'
    assert_no_match 'Karel', response.body
  end

  test "csv: admin stahne i archivovanou anketu" do
    sign_in @admin
    get :index, params: { form: 'stara', style: 'csv' }
    assert_response :success
    assert_match 'Karel', response.body
  end
end

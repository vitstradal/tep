require 'test_helper'

class SosnaSolverControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Sosna::SolverController

  # platné parametry přihlášky (papírové zasílání domů)
  def solver_params(email, grade: 5, paper_jr: '0', paper_pi: '0')
    {
      sosna_solver: { name: 'Jan', last_name: 'Novak', email: email,
                      birth: "1.1.#{Date.today.year - 12}", grade: "#{grade}. třída",
                      grade_num: grade.to_s, where_to_send: 'home', street: 'X', num: '1',
                      city: 'Praha', psc: '100 00', state: 'cz',
                      paper_jr: paper_jr, paper_pi: paper_pi },
      souhlasim: '1',
      school: { id: 'jina' },
      sosna_school: { name: 'ZS Test', short: 'ZST', street: 'S', num: '2',
                      city: 'Praha', psc: '100 00', state: 'cz' }
    }
  end

  test "city_group merges prague parts, keeps dashed towns" do
    assert_equal 'Praha', Sosna::School.new(city: 'Praha 5').city_group
    assert_equal 'Praha', Sosna::School.new(city: 'Praha 4 - Modřany').city_group
    assert_equal 'Praha', Sosna::School.new(city: 'Praha').city_group
    assert_equal 'Ostrava', Sosna::School.new(city: 'Ostrava-Vítkovice').city_group
    assert_equal 'Brno', Sosna::School.new(city: 'Brno-Líšeň').city_group
    assert_equal 'Frýdek-Místek', Sosna::School.new(city: 'Frýdek-Místek').city_group
    assert_equal 'Kostelec nad Labem', Sosna::School.new(city: 'Kostelec nad Labem').city_group
    assert_equal '', Sosna::School.new(city: nil).city_group
  end

  test "city_part_short abbreviates parts, nil without part" do
    assert_equal 'P10', Sosna::School.new(city: 'Praha 10').city_part_short
    assert_equal 'O-Vítkovice', Sosna::School.new(city: 'Ostrava-Vítkovice').city_part_short
    assert_equal 'P4 - Modřany', Sosna::School.new(city: 'Praha 4 - Modřany').city_part_short
    assert_nil Sosna::School.new(city: 'Praha').city_part_short
    assert_nil Sosna::School.new(city: 'Brno').city_part_short
    assert_nil Sosna::School.new(city: 'Frýdek-Místek').city_part_short

    s = Sosna::School.new(city: 'Praha 10', name: 'ZS A', street: 'X', num: '1', psc: '100 00', short: 'ZSA')
    assert_equal 'P10, ZS A, X 1, 100 00, ZSA', s.select_label
    bez = Sosna::School.new(city: 'Brno', name: 'ZS C', street: 'Z', num: '3', psc: '600 00', short: 'ZSC')
    assert_equal 'ZS C, Z 3, 600 00, ZSC', bez.select_label
  end

  test "new form has city filter select with grouped cities" do
    Sosna::Config.create!(key: 'annual', value: '33')
    Sosna::School.create!(name: 'ZS A', city: 'Praha 5', street: 'X', num: '1', psc: '150 00')
    Sosna::School.create!(name: 'ZS B', city: 'Praha 10', street: 'Y', num: '2', psc: '100 00')
    Sosna::School.create!(name: 'ZS C', city: 'Brno', street: 'Z', num: '3', psc: '600 00')
    get :new
    assert_response :success
    body = response.body
    assert_match 'id="school_city"', body
    assert_equal 1, body.scan('<option value="Praha">Praha</option>').size, 'Praha sloučená jednou'
    assert_match '<option value="Brno">Brno</option>', body
    assert_match 'data-city="Praha"', body       # opce školy nesou město
    assert_match '<option value="jine">Jiné město</option>', body
  end

  test "labels page offers annual select with existing annuals" do
    org = User.new(email: 'org-lab@x.cz', password: 'password123', roles: [:org])
    org.skip_confirmation!
    org.save!
    Sosna::Config.create!(key: 'annual', value: '33')
    %w[32 33].each do |roc|
      Sosna::Solver.create!(name: 'J', last_name: 'N', annual: roc, grade_num: '5',
                            email: "r#{roc}@x.cz", where_to_send: 'school')
    end
    sign_in org
    get :labels
    assert_response :success
    assert_match '<option selected="selected" value="33">33</option>', response.body
    assert_match '<option value="32">32</option>', response.body
  end

  test "registration stores paper level choices" do
    Sosna::Config.create!(key: 'annual', value: '33')
    post :create, params: solver_params('junior@seznam.cz', grade: 5, paper_jr: '1', paper_pi: '0')
    solver = Sosna::Solver.find_by(email: 'junior@seznam.cz')
    assert solver, 'řešitel se má založit'
    assert_equal true,  solver.paper_jr
    assert_equal false, solver.paper_pi
  end

  test "registration requires at least one paper level for paper delivery" do
    Sosna::Config.create!(key: 'annual', value: '33')
    post :create, params: solver_params('nic@seznam.cz', grade: 5)
    assert_nil Sosna::Solver.find_by(email: 'nic@seznam.cz')
    assert_redirected_to action: :new   # zpět do formuláře s chybou
  end

  test "registration drops junior leaflet above 6th grade" do
    Sosna::Config.create!(key: 'annual', value: '33')
    post :create, params: solver_params('velky@seznam.cz', grade: 8, paper_jr: '1', paper_pi: '1')
    solver = Sosna::Solver.find_by(email: 'velky@seznam.cz')
    assert solver
    assert_equal false, solver.paper_jr, 'junior je jen do 6. ročníku'
    assert_equal true,  solver.paper_pi
  end

  test "solver registration takes over unverified friend account" do
    # neověřený přítel Pikomatu (jako po friend#register)
    friend_user = User.new(email: 'kid@seznam.cz', password: SecureRandom.hex(16))
    friend_user.skip_confirmation_notification!
    friend_user.save!
    Friend.create!(nick: 'Kid', user: friend_user)
    Sosna::Config.create!(key: 'annual', value: '33')

    post :create, params: {
      sosna_solver: { name: 'Jan', last_name: 'Novak', email: 'kid@seznam.cz',
                      birth: "1.1.#{Date.today.year - 12}", grade: 'sedmá třída',
                      grade_num: '7', where_to_send: 'home', street: 'X', num: '1',
                      city: 'Praha', psc: '100 00', state: 'cz', paper_pi: '1' },
      souhlasim: '1',
      school: { id: 'jina' },
      sosna_school: { name: 'ZS Test', short: 'ZST', street: 'S', num: '2',
                      city: 'Praha', psc: '100 00', state: 'cz' }
    }
    assert_redirected_to action: :create_tnx, send_first: true

    friend_user.reload
    assert friend_user.confirmed_at.present?, 'převzatý účet má být potvrzen'
    assert friend_user.user?, 'převzatý účet má dostat roli :user'
    solver = Sosna::Solver.find_by(email: 'kid@seznam.cz')
    assert_equal friend_user.id, solver.user_id
  end
end

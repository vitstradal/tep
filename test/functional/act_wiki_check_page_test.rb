require 'test_helper'

class ActWikiCheckPageTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventsController

  setup do
    @dir = Dir.mktmpdir
    Rugged::Repository.init_at(@dir, :bare)
    @saved = Giwi.giwis.dup
    @main = Giwi.new('main', { path: @dir, url: '', ext: '.wiki', read: :anon })
    Giwi.giwis.replace(main: @main)
    @main.set_files({ 'tabor/2026.wiki' => "= Tábor =\n" }, 'init', 'A <a@b.cz>')
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    @event = Act::Event.create!(title: 'Tábor 2026', event_category: 'tabor', event_info_url: '/tabor/2026',
                                event_start: Date.current, event_end: Date.current + 1)
    @morg = User.new(email: 'morg@x.cz', password: 'password123')
    @morg.skip_confirmation!
    @morg.save!
    @morg.roles << :org << :morg
    @morg.save!
  end

  teardown do
    Giwi.giwis.replace(@saved)
    FileUtils.remove_entry(@dir)
  end

  test "morg sees problems with notes and fixes {{akce}} from the page" do
    sign_in @morg
    get :wiki_check
    assert_response :success
    assert_select 'td', /chybí \{\{akce\}\}/
    assert_select 'button', /Doplnit \{\{akce\}\} na 1 stránek/
    post :wiki_check_fix
    assert_redirected_to act_events_wiki_check_path
    assert_equal "{{akce}}\n= Tábor =\n", @main.get_page('tabor/2026.wiki').first
    assert_match 'morg@x.cz', Rugged::Repository.new(@dir).last_commit.author[:email]
    get :wiki_check
    assert_select 'p', /Všechny stránky akcí jsou v pořádku/
  end

  test "events overview has a button to the check for morg" do
    sign_in @morg
    get :index
    assert_select 'a[href=?]', act_events_wiki_check_path, /Kontrola wiki akcí/
  end

  test "errors are listed first and fixable pages are not listed by path" do
    Act::Event.create!(title: 'Stará', event_category: 'tabor', event_info_url: '/neni/tu',
                       event_start: Date.current - 400, event_end: Date.current - 399)
    sign_in @morg
    get :wiki_check
    rows = css_select('table tr')[1..]
    assert_equal %w[danger warning], rows.map { |r| r['class'] }
    assert_no_match 'tabor/2026.wiki', response.body
  end

  test "plain org cannot run the check" do
    org = User.new(email: 'org@x.cz', password: 'password123')
    org.skip_confirmation!
    org.save!
    org.roles << :org
    org.save!
    sign_in org
    get :index
    assert_select 'a[href=?]', act_events_wiki_check_path, 0
    post :wiki_check_fix
    assert_equal "= Tábor =\n", @main.get_page('tabor/2026.wiki').first
  end
end

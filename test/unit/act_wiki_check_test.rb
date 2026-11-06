require 'test_helper'
require 'act_wiki_check'

class ActWikiCheckTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    Rugged::Repository.init_at(@dir, :bare)
    @saved = Giwi.giwis.dup
    @main = Giwi.new('main', { path: @dir, url: '', ext: '.wiki' })
    Giwi.giwis.replace(main: @main)
    @main.set_files({ 'tabor/2026.wiki' => "{{akce}}\n= Tábor =\n", 'soustredeni/podzim.wiki' => "= Podzim =\n",
                      'setkani/utery.wiki' => "= Úterý =\n" }, 'init', 'A <a@b.cz>')
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    mk = ->(title, url) { Act::Event.create!(title: title, event_category: 'tabor', event_info_url: url, event_start: Date.current, event_end: Date.current + 1) }
    @tabor = mk.('Tábor', '/tabor/2026')
    @podzim = mk.('Podzim', 'https://pikomat.mff.cuni.cz/soustredeni/podzim#h5')
    @ut1 = mk.('Úterý 1', '/setkani/utery')
    @ut2 = mk.('Úterý 2', '/setkani/utery')
    @gone = mk.('Nic', '/neni/tu')
    @ext = mk.('Jinde', 'https://example.com/x')
  end

  teardown do
    Giwi.giwis.replace(@saved)
    FileUtils.remove_entry(@dir)
  end

  test "reports status per page and fix adds {{akce}} once per page" do
    items = ActWikiCheck.new(Act::Event.order(:id)).items.to_h { |i| [i.event.id, i] }
    assert_equal :ok, items[@tabor.id].status
    assert_equal :no_macro, items[@podzim.id].status
    assert_equal 'soustredeni/podzim.wiki', items[@podzim.id].page
    assert_equal :no_macro, items[@ut1.id].status
    assert items[@ut1.id].shared
    refute items[@tabor.id].shared
    assert_equal :missing, items[@gone.id].status
    assert_equal :external, items[@ext.id].status

    fixed = ActWikiCheck.new(Act::Event.order(:id)).fix!
    assert_equal 2, fixed.size
    assert_equal "{{akce}}\n= Podzim =\n", @main.get_page('soustredeni/podzim.wiki').first
    assert_equal "{{akce}}\n= Úterý =\n", @main.get_page('setkani/utery.wiki').first
    assert_equal "{{akce}}\n= Tábor =\n", @main.get_page('tabor/2026.wiki').first
    assert_empty ActWikiCheck.new(Act::Event.order(:id)).fix!
  end

  test "event is found for its wiki page also when the link has host or anchor" do
    assert_equal @podzim, Act::Event.for_wiki_page(:event_info_url, '/soustredeni/podzim')
    assert_equal @tabor, Act::Event.for_wiki_page(:event_info_url, '/tabor/2026')
    assert_equal @ut2, Act::Event.for_wiki_page(:event_info_url, '/setkani/utery')
    assert_nil Act::Event.for_wiki_page(:event_info_url, '/tabor/20')
    assert_nil Act::Event.for_wiki_page(:event_info_url, '/soustredeni/podzi')
  end
end

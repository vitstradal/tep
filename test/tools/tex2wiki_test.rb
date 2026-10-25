# ruby -Itest test/tools/tex2wiki_test.rb
require 'minitest/autorun'
require 'tmpdir'
require_relative '../../tools/tex2wiki'
require_relative '../../tools/tex2wiki-sync'

class Tex2WikiTest < Minitest::Test
  def conv(tex, **opt)
    Tex2Wiki::Converter.new(rocnik: 41, **opt).convert(tex)
  end

  def test_math_macros_starting_with_m_survive
    assert_includes conv('$8 \mid a$, $x \medspace y$'), '$8 \mid a$'
  end

  def test_units_in_math_and_text
    assert_includes conv('$2\cm$'), '$2\,{\rm cm}$'
    assert_includes conv('má 2\cm'), "má 2\u00a0cm"
  end

  def test_fractions_and_binom_stay_tex
    out = conv('$\frac{a}{b} = \binom{n}{k} = {n \choose k}$')
    assert_includes out, '\frac{a}{b}'
    assert_includes out, '\binom{n}{k}'
  end

  def test_task_heading_meta_and_anchor
    c = Tex2Wiki::Converter.new(rocnik: 41)
    out = c.convert("\\ses3{12. ledna 2026}\n\\ul2\nText\n\\ulend")
    assert_equal({ kind: :zad, serie: 3, termin: '12. ledna 2026', ul: 2 }, c.meta)
    assert_includes out, '=== Úloha č. 2 === #ul2'
  end

  def test_vz_link_after_task
    c = Tex2Wiki::Converter.new(rocnik: 41)
    c.vz_link = '/archiv/rocnik41/vz3'
    assert_includes c.convert("\\ul2\nText\n\\ulend"), '[[/archiv/rocnik41/vz3#ul2|→ vzorové řešení]]'
  end

  def test_images_and_refs
    c = Tex2Wiki::Converter.new(rocnik: 41)
    out = c.convert("viz obr.~\\obref{zad111}\n\\obrazky{zad1.11|zad111}")
    assert_includes out, '[[#zad111|1]]'
    assert_includes out, '[[Image(archiv/rocnik41/zad1.11.png,id=zad111)]]'
    assert_equal ['zad1.11'], c.images
  end

  def test_junior_image_caption
    out = conv('\obrazky{obrazky/zad3.11|8cm|Obrázek s~trojúhelníky}', junior: true)
    assert_includes out, '[[Image(archiv/rocnik41/junior/zad3.11.png,id=zad311)]]'
    assert_includes out, '**Obrázek s~trojúhelníky**'
  end

  def test_lists
    out = conv("\\itemsnum{}\n\\item první\n\n\\item druhá\n\\enditems")
    assert_includes out, " 1. první\n 1. druhá"
  end

  def test_line_that_looks_like_wiki_list_is_escaped
    refute_match(/^1\. způsob/, conv("Úvod.\n\n1. způsob: nejdřív"))
  end

  def test_comments_and_fonts
    out = conv("{\\bf tučně} a {\\it kurzíva} % poznámka\n")
    assert_equal "**tučně** a ''kurzíva''\n", out
  end

  def test_halign_to_table
    out = conv('\halign{$#$&&$#$\cr 1&2\cr 3&4\cr}')
    assert_includes out, '|| $1$ || $2$ ||'
  end

  def test_unknown_macro_warns
    c = Tex2Wiki::Converter.new(rocnik: 41)
    c.convert('\neznamemakro x')
    assert_includes c.warnings, 'neznámé makro \neznamemakro'
  end
end

class Tex2WikiSyncTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @web = File.join(@dir, 'web')
    @src = File.join(@dir, 'src')
    FileUtils.mkdir_p([File.join(@web, 'archiv/rocnik41'), File.join(@src, '41_1_k')])
    File.write(File.join(@src, '41_1_k/zad2.tex'), "\\ses2{1. 12. 2025}\n\\ul1\nZadání.\n\\ulend\n")
    File.write(File.join(@src, '41_1_k/vz2.tex'), "\\vr2\n\\ur1\nZadání.\n\\reseni Řešení.\n")
    index('{{archiv  41|zrv|z}}')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def index(line)
    File.write(File.join(@web, 'archiv/index.wiki'), "= Archiv =\n\n#{line}\n")
  end

  def sync(**opt)
    Tex2Wiki::Sync.new(web: @web, srcs: [@src], write: true, out: StringIO.new, **opt)
  end

  def page(name)
    File.join(@web, 'archiv/rocnik41', "#{name}.wiki")
  end

  def test_publishes_only_flagged
    sync.run(41)
    assert File.exist?(page('zad2'))
    refute File.exist?(page('vz2'))
    refute_includes File.read(page('zad2')), 'vzorové řešení'
  end

  def test_publishing_solution_links_tasks
    sync.run(41)
    sync.publish(41, 2, 'r')
    assert_includes File.read(File.join(@web, 'archiv/index.wiki')), '{{archiv  41|zrv|zr}}'
    sync.run(41)
    assert File.exist?(page('vz2'))
    assert_includes File.read(page('zad2')), '[[/archiv/rocnik41/vz2#ul1|→ vzorové řešení]]'
  end

  def test_replaces_pdf_redirect_stub
    File.write(page('zad2'), "= Zad2 =\n\n{{redirect archiv/rocnik41/zad2.pdf}}\n")
    sync.run(41)
    assert_includes File.read(page('zad2')), '=== Úloha č. 1 ==='
  end

  def test_keeps_hand_edited_pages
    sync.run(41)
    File.write(page('zad2'), File.read(page('zad2')) + "ruční doplněk\n")
    File.write(File.join(@src, '41_1_k/zad2.tex'), "\\ses2{1. 12. 2025}\n\\ul1\nJiné zadání.\n\\ulend\n")
    sync.run(41)
    assert_includes File.read(page('zad2')), 'ruční doplněk'
    sync(force: true).run(41)
    assert_includes File.read(page('zad2')), 'Jiné zadání.'
  end

  def test_regenerates_own_unedited_pages
    sync.run(41)
    File.write(File.join(@src, '41_1_k/zad2.tex'), "\\ses2{1. 12. 2025}\n\\ul1\nOpravené zadání.\n\\ulend\n")
    sync.run(41)
    assert_includes File.read(page('zad2')), 'Opravené zadání.'
  end

  def test_next_year_task_in_last_leaflet_is_ignored
    FileUtils.mkdir_p(File.join(@src, '41_7_k'))
    File.write(File.join(@src, '41_7_k/zad1.tex'), "\\ses1{20. října 2026}\n\\ul1\nZ příštího ročníku.\n\\ulend\n")
    index('{{archiv  41|z|z}}')
    sync.run(41)
    refute File.exist?(page('zad1'))
  end

  def test_dry_run_writes_nothing
    Tex2Wiki::Sync.new(web: @web, srcs: [@src], out: StringIO.new).run(41)
    refute File.exist?(page('zad2'))
  end
end

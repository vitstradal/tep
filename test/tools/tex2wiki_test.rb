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
    assert_includes out, "**Obrázek s\u00a0trojúhelníky**"
  end

  def test_image_width_from_leaflet
    c = Tex2Wiki::Converter.new(rocnik: 41)
    c.convert('\obrazky{zad3.11|8cm|Popisek} \XeTeXpdffile zad1ml-21.pdf width .5\hsize')
    assert_equal 8.0, c.image_cm('zad3.11')
    assert_equal 8.5, c.image_cm('zad1ml-21')
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

  def test_subheadings
    assert_includes conv("\\podnadpis{Jak sčítat?}\nText"), "==== Jak sčítat? ===="
    assert_includes conv("\\podnadpis Jak násobit\\par Text"), "==== Jak násobit ===="
  end

  def test_halign_to_table
    out = conv('\halign{$#$&&$#$\cr 1&2\cr 3&4\cr}')
    assert_includes out, '|| $1$ || $2$ ||'
  end

  def test_latex_environments
    c = Tex2Wiki::Converter.new(rocnik: 42, junior: true)
    out = c.convert("\\begin{table}[ht]\n\\centering\n\\begin{tabular}{c|c}\n2 & 7 \\\\\n\\hline\n9 & 5 \\\\\n\\end{tabular}\n\\end{table}\n" \
                    "\\begin{figure}\n\\includegraphics[width=0.5\\linewidth]{obrazky/vz1j-51.pdf}\n\\caption{}\n\\label{fig:x}\n\\end{figure}")
    assert_includes out, '|| 2 || 7 ||'
    assert_includes out, '[[Image(archiv/rocnik42/junior/vz1j-51.png)]]'
    assert_equal 8.5, c.image_cm('obrazky/vz1j-51')
    assert_empty c.warnings
  end

  def test_tie_quotes_footnote_dots
    out = conv("a~dále \\uv{Ahoj,\nkapitáne} vět.\\footnote{$^*$}{Dva\nslova}\n\n$x\\tecky{1em}>\\tecky y$ a \\tecky{1cm}.")
    assert_includes out, "a\u00a0dále „Ahoj,\nkapitáne“ vět.$^*$"
    assert_includes out, "''$^*$ Dva slova''"
    assert_includes out, '$x\\ldots\\ldots>\\ldots\\ldots y$'
    assert_includes out, 'a  …… .'
  end

  def test_footnote_text_ends_the_task
    out = conv("\\ul1\nText\\footnote{Pozn.}\n\nDál.\n\\ulend\n\\ul2\nB\n\\ulend")
    assert_match(/Dál\.\n\n''\* Pozn\.''\n\n=== Úloha č\. 2/, out)
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

  def test_gen_only_creates_new_pages
    sync.run(41)
    File.write(File.join(@src, '41_1_k/zad2.tex'), "\\ses2{1. 12. 2025}\n\\ul1\nOpravené zadání.\n\\ulend\n")
    res = sync.run(41, mode: :gen)
    refute_includes File.read(page('zad2')), 'Opravené zadání.'
    assert_equal ['archiv/rocnik41/zad2.wiki'], res[:outdated]
    assert_equal ['41/2r'], res[:unpublished]
  end

  def test_publish_regenerates_tasks_in_gen_mode
    s = sync
    s.run(41)
    s.publish(41, 2, 'r')
    s.run(41, mode: :gen)
    assert_includes File.read(page('zad2')), '→ vzorové řešení'
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

class Tex2WikiMirrorTest < Minitest::Test
  def test_refresh_waits_for_stamp
    Dir.mktmpdir do |d|
      FileUtils.touch(File.join(d, 'refresh'))
      writer = Thread.new { sleep 0.2; File.write(File.join(d, 'stamp'), "2026-10-26 3 projektů\n") }
      out = StringIO.new
      Tex2Wiki::Mirror.refresh(d, timeout: 5, poll: 0.05, out: out)
      writer.join
      assert_includes out.string, 'hotovo (2026-10-26 3 projektů)'
    end
  end

  def test_refresh_gives_up_and_without_trigger_does_nothing
    Dir.mktmpdir do |d|
      out = StringIO.new
      Tex2Wiki::Mirror.refresh(d, out: out)
      assert_empty out.string
      FileUtils.touch(File.join(d, 'refresh'))
      Tex2Wiki::Mirror.refresh(d, timeout: 0.1, poll: 0.05, out: out)
      assert_includes out.string, 'Zrcadlo neodpovídá'
    end
  end
end

class Tex2WikiRepoTest < Minitest::Test
  def test_current_rocnik
    assert_equal 42, Tex2Wiki::Repo.current_rocnik(Date.new(2026, 10, 25))
    assert_equal 41, Tex2Wiki::Repo.current_rocnik(Date.new(2026, 6, 1))
  end

  def test_commit_and_clean
    Dir.mktmpdir do |d|
      origin = File.join(d, 'web.git')
      work = File.join(d, 'work')
      system('git', 'init', '-q', '--bare', origin)
      system('git', 'clone', '-q', origin, work, err: File::NULL)
      FileUtils.mkdir_p(File.join(work, 'archiv'))
      File.write(File.join(work, 'archiv/index.wiki'), "{{archiv  42|z}}\n")
      system('git', '-C', work, 'add', '-A')
      system('git', '-C', work, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'init')
      system('git', '-C', work, 'push', '-q', 'origin', 'HEAD', err: File::NULL)
      clone = File.join(d, 'clone')
      system('git', 'clone', '-q', origin, clone)
      repo = Tex2Wiki::Repo.new(clone)
      assert_equal [42], repo.recent_rocniky.select { |r| r == 42 }
      File.write(File.join(clone, 'archiv/zad1.wiki'), "x\n")
      assert repo.dirty?
      repo.clean
      refute repo.dirty?
      File.write(File.join(clone, 'archiv/zad1.wiki'), "x\n")
      ENV['GIT_AUTHOR_NAME'] = ENV['GIT_COMMITTER_NAME'] = 't'
      ENV['GIT_AUTHOR_EMAIL'] = ENV['GIT_COMMITTER_EMAIL'] = 't@t'
      assert_equal ['archiv/zad1.wiki'], repo.commit_and_push
      assert_includes `git -C #{origin} log --format=%s`, 'archiv: zad1 (tex2wiki)'
    end
  end
end

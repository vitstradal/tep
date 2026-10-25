require 'test_helper'
require 'giwi'

class GiwiTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "the truth" do
    giwi = Giwi.new('test', {nogit: true})
    assert_equal "1A45", giwi.send(:_patch_part, "A", "12345", '1.1-1.3')
    assert_equal "1A345", giwi.send(:_patch_part, "A", "12345", '1.1-1.2')
    assert_equal "1A345\n1234", giwi.send(:_patch_part, "A", "12345\n1234", '1.1-1.2')
    assert_equal "1A34", giwi.send(:_patch_part, "A", "12345\n1234", '1.1-2.2')
    assert_equal "A12345\n1234", giwi.send(:_patch_part, "A", "12345\n1234", '1')
    assert_equal "12345\nA1234", giwi.send(:_patch_part, "A", "12345\n1234", '2')
    assert_equal "12345\n1234\nA", giwi.send(:_patch_part, "A", "12345\n1234", '3')
    assert_equal "12345\n1234\nA", giwi.send(:_patch_part, "A", "12345\n1234\n", '3')
    assert_equal "12345\n1234\nA", giwi.send(:_patch_part, "A", "12345\n1234\n", '3-6')
    assert_equal "12345\nA", giwi.send(:_patch_part, "A", "12345\n1234\n", '2-6')
    assert_equal "12345\nA234", giwi.send(:_patch_part, "A", "12345\n1234\n1234", '2-3.1')
    assert_equal "12345\nA", giwi.send(:_patch_part, "A", "12345\n1234\n1234", '2-3.11')
    assert true
  end
end

class GiwiSetFilesTest < ActiveSupport::TestCase
  test "set_files commits several files at once" do
    Dir.mktmpdir do |dir|
      Rugged::Repository.init_at(dir, :bare)
      giwi = Giwi.new('t', { path: dir })
      giwi.set_files({ 'archiv/index.wiki' => "{{archiv  42|z}}\n" }, 'init', 'A <a@b.cz>')
      giwi.set_files({ 'archiv/rocnik42/vysl1.wiki' => "= V =\n", 'archiv/index.wiki' => "{{archiv  42|zv}}\n" }, 'vysl', 'A <a@b.cz>')
      assert_equal "{{archiv  42|zv}}\n", giwi.get_page('archiv/index.wiki').first
      assert_equal "= V =\n", giwi.get_page('archiv/rocnik42/vysl1.wiki').first
      head = giwi.repo.branches['master'].target
      assert_equal 'vysl', head.message
      assert_equal 1, head.parents.size
    end
  end
end

class ArchivIndexFlagTest < ActiveSupport::TestCase
  def flag(*args)
    Sosna::SolutionController.archiv_index_flag(*args)
  end

  test "adds v to the series" do
    idx = "{{archiv  42|zr|z}}\n{{archiv_junior  42|zr}}\n"
    assert_equal "{{archiv  42|zrv|z}}\n{{archiv_junior  42|zr}}\n", flag(idx, '42', false, 1, 'v')
    assert_equal "{{archiv  42|zr|z}}\n{{archiv_junior  42|zr|v}}\n", flag(idx, '42', true, 2, 'v')
    assert_equal idx, flag(flag(idx, '42', false, 1, 'v'), '42', false, 1, 'v').sub('zrv', 'zr')
    assert_nil flag(idx, '43', false, 1, 'v')
  end
end

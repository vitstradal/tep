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

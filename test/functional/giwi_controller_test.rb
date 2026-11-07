require 'test_helper'

class GiwiControllerTest < ActionController::TestCase
  # Replace this with your real tests.
  test "the truth" do
    #@controller._patch_part('ahoj', 'bhoj', '1-2')
    assert true
  end

  test "adventomat_kalendar macro inserts only an empty container" do
    html = @controller.send(:_template_adventomat_kalendar, {}, { '0' => '2026' })
    assert_equal '<div id="adventomat-app" data-year="2026"><p class="grey">Načítám adventomat…</p></div>', html
    assert_match 'chybí rok', @controller.send(:_template_adventomat_kalendar, {}, { '0' => '"><script>' })
  end
end

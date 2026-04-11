require "test_helper"

class RolesHelperTest < ActionView::TestCase
  include RolesHelper

  setup do
    @project = projects(:acme)
    Current.project = @project
    @ceo = roles(:ceo)
    @cto = roles(:cto)
  end

  test "options_for_role_select returns full active tree" do
    options = options_for_role_select
    ids = options.map(&:last)
    assert_includes ids, @ceo.id
    assert_includes ids, @cto.id
  end

  # Regression: when the only root role is terminated, the helper must
  # still surface its active descendants — otherwise the goal form shows
  # an empty "Assigned Role" select even though live roles exist.
  test "options_for_role_select surfaces active children of a terminated root" do
    @ceo.update!(status: :terminated)

    options = options_for_role_select
    ids = options.map(&:last)

    refute_includes ids, @ceo.id, "terminated root should be hidden"
    assert_includes ids, @cto.id, "active child of a terminated root must still be selectable"
  end

  test "options_for_role_select does not indent children under a hidden parent" do
    @ceo.update!(status: :terminated)

    options = options_for_role_select
    cto_label = options.find { |(_label, id)| id == @cto.id }.first

    assert_equal "CTO", cto_label, "child rendered at depth 0 when parent is hidden"
  end

  test "options_for_role_select with scope :all includes terminated roles" do
    @ceo.update!(status: :terminated)

    options = options_for_role_select(scope: :all)
    ids = options.map(&:last)

    assert_includes ids, @ceo.id
    assert_includes ids, @cto.id
  end

  test "options_for_role_select honors exclude with its subtree" do
    options = options_for_role_select(exclude: @cto, scope: :all)
    ids = options.map(&:last)

    refute_includes ids, @cto.id
    @cto.descendant_ids.each do |descendant_id|
      refute_includes ids, descendant_id
    end
    assert_includes ids, @ceo.id
  end
end

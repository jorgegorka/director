require "test_helper"

class ConfigVersionTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @user = users(:one)
    @role_version = config_versions(:role_edit_version)
    @budget_version = config_versions(:agent_budget_version)
  end

  # --- Validations ---

  test "valid with company, versionable, action, and snapshot" do
    version = ConfigVersion.new(
      company: @company,
      versionable: roles(:cto),
      action: "update",
      snapshot: { title: "CTO" }
    )
    assert version.valid?
  end

  test "invalid without action" do
    version = ConfigVersion.new(
      company: @company,
      versionable: roles(:cto),
      action: nil,
      snapshot: { title: "CTO" }
    )
    assert_not version.valid?
  end

  test "invalid with unrecognized action" do
    version = ConfigVersion.new(
      company: @company,
      versionable: roles(:cto),
      action: "destroy",
      snapshot: { title: "CTO" }
    )
    assert_not version.valid?
  end

  test "accepts create, update, and rollback actions" do
    %w[create update rollback].each do |action|
      version = ConfigVersion.new(
        company: @company,
        versionable: roles(:cto),
        action: action,
        snapshot: { title: "CTO" }
      )
      assert version.valid?, "Expected action '#{action}' to be valid"
    end
  end

  # --- Associations ---

  test "belongs to company via Tenantable" do
    assert_equal @company, @role_version.company
  end

  test "belongs to versionable (Role)" do
    assert_equal roles(:cto), @role_version.versionable
  end

  test "belongs to author (User)" do
    assert_equal @user, @role_version.author
  end

  test "author is optional" do
    version = ConfigVersion.new(
      company: @company,
      versionable: roles(:cto),
      action: "update",
      snapshot: { title: "CTO" },
      author: nil
    )
    assert version.valid?
  end

  # --- Scopes ---

  test "reverse_chronological returns newest first" do
    versions = ConfigVersion.reverse_chronological
    if versions.count > 1
      assert versions.first.created_at >= versions.last.created_at
    end
  end

  test "for_versionable returns versions for specific record" do
    versions = ConfigVersion.for_versionable(roles(:cto))
    versions.each { |v| assert_equal roles(:cto), v.versionable }
  end

  # --- Methods ---

  test "restorable_attributes excludes id and timestamps" do
    attrs = @role_version.restorable_attributes
    assert_not_includes attrs.keys, "id"
    assert_not_includes attrs.keys, "created_at"
    assert_not_includes attrs.keys, "updated_at"
    assert_not_includes attrs.keys, "company_id"
  end

  test "diff_summary returns array of changes" do
    summary = @role_version.diff_summary
    assert_kind_of Array, summary
    assert summary.any?
    summary.each do |change|
      assert change.key?(:attribute)
      assert change.key?(:from)
      assert change.key?(:to)
    end
  end

  test "restore! applies snapshot attributes to versionable" do
    Current.company = @company

    role = roles(:cto)
    role.update!(description: "Temporary change")
    assert_equal "Temporary change", role.description

    @role_version.restore!
    role.reload
    assert_equal "Chief Technology Officer", role.description
  ensure
    Current.company = nil
  end

  # --- Deletion ---

  test "destroying company destroys config versions" do
    version_count = @company.config_versions.count
    assert version_count > 0
    assert_difference "ConfigVersion.count", -version_count do
      @company.destroy
    end
  end

  # --- ConfigVersioned concern (via Role) ---

  test "updating role creates a config version" do
    Current.company = @company
    role = roles(:cto)
    assert_difference "ConfigVersion.count" do
      role.update!(description: "New description for versioning test")
    end
    version = ConfigVersion.where(versionable: role).order(:created_at).last
    assert_equal "update", version.action
    assert_equal "New description for versioning test", version.snapshot["description"]
  ensure
    Current.company = nil
  end

  test "config version changeset records old and new values" do
    Current.company = @company
    role = roles(:cto)
    old_desc = role.description
    role.update!(description: "Changed description")
    version = ConfigVersion.where(versionable: role).order(:created_at).last
    assert_equal [ old_desc, "Changed description" ], version.changeset["description"]
  ensure
    Current.company = nil
  end

  test "updating non-governance attribute does not create version" do
    Current.company = @company
    role = roles(:cto)
    initial_count = ConfigVersion.where(versionable: role).count
    # Touch only updated_at — should_version? filters out updated_at-only changes
    role.touch
    assert_equal initial_count, ConfigVersion.where(versionable: role).count
  ensure
    Current.company = nil
  end
end

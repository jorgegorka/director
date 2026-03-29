require "test_helper"

class RoleTemplateRegistryTest < ActiveSupport::TestCase
  teardown do
    RoleTemplateRegistry.reset!
  end

  # --- .all ---

  test "all returns five templates" do
    templates = RoleTemplateRegistry.all
    assert_equal 5, templates.size
  end

  test "all returns frozen array" do
    templates = RoleTemplateRegistry.all
    assert templates.frozen?
  end

  test "all includes engineering template" do
    keys = RoleTemplateRegistry.all.map(&:key)
    assert_includes keys, "engineering"
  end

  test "all includes marketing template" do
    keys = RoleTemplateRegistry.all.map(&:key)
    assert_includes keys, "marketing"
  end

  test "all includes operations template" do
    keys = RoleTemplateRegistry.all.map(&:key)
    assert_includes keys, "operations"
  end

  test "all includes finance template" do
    keys = RoleTemplateRegistry.all.map(&:key)
    assert_includes keys, "finance"
  end

  test "all includes hr template" do
    keys = RoleTemplateRegistry.all.map(&:key)
    assert_includes keys, "hr"
  end

  test "all caches results across calls" do
    first_call = RoleTemplateRegistry.all
    second_call = RoleTemplateRegistry.all
    assert_same first_call, second_call
  end

  # --- .find ---

  test "find returns template by key" do
    template = RoleTemplateRegistry.find("engineering")
    assert_equal "engineering", template.key
    assert_equal "Engineering", template.name
  end

  test "find accepts symbol key" do
    template = RoleTemplateRegistry.find(:marketing)
    assert_equal "marketing", template.key
  end

  test "find raises TemplateNotFound for unknown key" do
    error = assert_raises(RoleTemplateRegistry::TemplateNotFound) do
      RoleTemplateRegistry.find("nonexistent")
    end
    assert_match(/nonexistent/, error.message)
  end

  # --- .keys ---

  test "keys returns all template keys" do
    keys = RoleTemplateRegistry.keys
    assert_equal 5, keys.size
    assert_includes keys, "engineering"
    assert_includes keys, "marketing"
    assert_includes keys, "operations"
    assert_includes keys, "finance"
    assert_includes keys, "hr"
  end

  # --- Template structure ---

  test "template has key name description and roles" do
    template = RoleTemplateRegistry.find("engineering")
    assert_respond_to template, :key
    assert_respond_to template, :name
    assert_respond_to template, :description
    assert_respond_to template, :roles
    assert_kind_of String, template.key
    assert_kind_of String, template.name
    assert_kind_of String, template.description
    assert_kind_of Array, template.roles
  end

  test "template description is not blank" do
    RoleTemplateRegistry.all.each do |template|
      assert template.description.present?, "#{template.key} has blank description"
    end
  end

  # --- Template roles structure ---

  test "each template has 4 to 7 roles" do
    RoleTemplateRegistry.all.each do |template|
      count = template.roles.size
      assert count >= 4 && count <= 7,
        "#{template.key} has #{count} roles, expected 4-7"
    end
  end

  test "role has title description job_spec parent and skill_keys" do
    role = RoleTemplateRegistry.find("engineering").roles.first
    assert_respond_to role, :title
    assert_respond_to role, :description
    assert_respond_to role, :job_spec
    assert_respond_to role, :parent
    assert_respond_to role, :skill_keys
  end

  test "each role has 3 to 5 skill keys" do
    RoleTemplateRegistry.all.each do |template|
      template.roles.each do |role|
        count = role.skill_keys.size
        assert count >= 3 && count <= 5,
          "#{template.key}/#{role.title} has #{count} skill_keys, expected 3-5"
      end
    end
  end

  test "each role has non-blank title and description" do
    RoleTemplateRegistry.all.each do |template|
      template.roles.each do |role|
        assert role.title.present?, "#{template.key} has role with blank title"
        assert role.description.present?, "#{template.key}/#{role.title} has blank description"
      end
    end
  end

  test "each role has multi-paragraph job_spec" do
    RoleTemplateRegistry.all.each do |template|
      template.roles.each do |role|
        paragraphs = role.job_spec.strip.split(/\n\n+/)
        assert paragraphs.size >= 2,
          "#{template.key}/#{role.title} job_spec has #{paragraphs.size} paragraphs, expected 2+"
      end
    end
  end

  test "first role in each template has nil parent (is root)" do
    RoleTemplateRegistry.all.each do |template|
      root = template.roles.first
      assert_nil root.parent, "#{template.key} first role '#{root.title}' should have nil parent"
    end
  end

  test "each template has exactly one root role" do
    RoleTemplateRegistry.all.each do |template|
      root_count = template.roles.count { |r| r.parent.nil? }
      assert_equal 1, root_count,
        "#{template.key} has #{root_count} root roles, expected 1"
    end
  end

  # --- Parent ordering validation ---

  test "all templates have valid parent ordering" do
    # This test implicitly passes if .all doesn't raise -- validation happens at load time.
    # Explicitly verify: for each template, every parent reference points to a title that appears earlier.
    RoleTemplateRegistry.all.each do |template|
      seen = Set.new
      template.roles.each do |role|
        if role.parent.present?
          assert_includes seen, role.parent,
            "#{template.key}: '#{role.title}' references parent '#{role.parent}' not yet seen"
        end
        seen << role.title
      end
    end
  end

  test "all parent references match actual role titles in same template" do
    RoleTemplateRegistry.all.each do |template|
      titles = template.roles.map(&:title).to_set
      template.roles.each do |role|
        next if role.parent.nil?
        assert_includes titles, role.parent,
          "#{template.key}: '#{role.title}' references parent '#{role.parent}' which is not in the template"
      end
    end
  end

  # --- Skill keys validation ---

  test "all skill keys reference existing builtin skills" do
    skill_files = Dir[Rails.root.join("db/seeds/skills/*.yml")]
    valid_keys = skill_files.map { |f| YAML.load_file(f)["key"] }.to_set

    RoleTemplateRegistry.all.each do |template|
      template.roles.each do |role|
        role.skill_keys.each do |key|
          assert_includes valid_keys, key,
            "#{template.key}/#{role.title} references unknown skill key '#{key}'"
        end
      end
    end
  end

  # --- Specific template content ---

  test "engineering template has correct role hierarchy" do
    template = RoleTemplateRegistry.find("engineering")
    titles = template.roles.map(&:title)
    assert_includes titles, "CTO"
    assert_includes titles, "VP Engineering"
    assert_includes titles, "Tech Lead"
    assert_includes titles, "Engineer"
    assert_includes titles, "QA"
  end

  test "marketing template has CMO as root" do
    template = RoleTemplateRegistry.find("marketing")
    assert_equal "CMO", template.roles.first.title
  end

  test "operations template has COO as root" do
    template = RoleTemplateRegistry.find("operations")
    assert_equal "COO", template.roles.first.title
  end

  test "finance template has CFO as root" do
    template = RoleTemplateRegistry.find("finance")
    assert_equal "CFO", template.roles.first.title
  end

  test "hr template has HR Director as root" do
    template = RoleTemplateRegistry.find("hr")
    assert_equal "HR Director", template.roles.first.title
  end

  # --- reset! ---

  test "reset clears cached templates" do
    first = RoleTemplateRegistry.all
    RoleTemplateRegistry.reset!
    second = RoleTemplateRegistry.all
    refute_same first, second
  end
end

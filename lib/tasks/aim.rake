load File.expand_path("../../test/aim/seed.rake", __dir__)

namespace :aim do
  desc "Seed known data for AIM diagnostic scenarios"
  task seed: :environment do
    AIMSeed.new.run
  end

  desc "Run AIM scenarios. Usage: rake aim:run SCENARIOS=all or SCENARIOS=id1,id2"
  task run: :environment do
    require_relative "../../test/aim/lib/runner"

    scenarios_file = Rails.root.join("test/aim/scenarios.yml")
    all_scenarios = YAML.load_file(scenarios_file).deep_symbolize_keys

    requested = ENV.fetch("SCENARIOS", "all")
    scenarios = all_scenarios[:scenarios]

    unless requested == "all"
      ids = requested.split(",").map(&:strip)
      scenarios = scenarios.select { |s| ids.include?(s[:id].to_s) }
      if scenarios.empty?
        puts "No scenarios matched: #{ids.join(', ')}"
        puts "Available: #{all_scenarios[:scenarios].map { |s| s[:id] }.join(', ')}"
        exit 1
      end
    end

    puts "AIM: Running #{scenarios.size} scenario(s)..."
    puts "     Estimated cost: ~$#{format('%.2f', scenarios.size * 0.03)} (#{scenarios.size} Claude calls)"
    puts

    runner = AIM::Runner.new(scenarios)
    results = runner.execute

    # Print summary
    passed = results.count { |r| r.status == "success" }
    failed = results.count { |r| r.status == "error" }
    total_cost = results.sum { |r| r.cost_cents || 0 }
    total_duration = results.sum { |r| r.duration_seconds || 0 }

    puts
    puts "=" * 60
    puts "AIM Results: #{passed} success, #{failed} error (#{results.size} total)"
    puts "Cost: $#{format('%.4f', total_cost / 100.0)} | Duration: #{total_duration.round(1)}s"
    puts "=" * 60

    results.each do |r|
      status_icon = r.status == "success" ? "PASS" : "FAIL"
      tools = r.tool_calls.map(&:tool).join(", ")
      puts "  [#{status_icon}] #{r.scenario_id} — tools: #{tools.presence || 'none'} (#{r.duration_seconds&.round(1)}s)"
      puts "         ERROR: #{r.error}" if r.error
    end

    # Write raw results
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    output_dir = Rails.root.join("test/aim/results/raw")
    FileUtils.mkdir_p(output_dir)
    output_file = output_dir.join("#{timestamp}.json")

    json_results = results.map do |r|
      {
        scenario_id: r.scenario_id,
        status: r.status,
        role_title: r.role_title,
        category: r.category,
        message: r.message,
        tool_calls: r.tool_calls.map { |tc| { tool: tc.tool, params: tc.params } },
        response: r.response,
        cost_cents: r.cost_cents,
        duration_seconds: r.duration_seconds,
        error: r.error
      }
    end

    File.write(output_file, JSON.pretty_generate(json_results))
    puts
    puts "Raw results: #{output_file}"
  end
end

load File.expand_path("../../test/aim/seed.rake", __dir__)

# Runs the given block with the Solid Queue `:execution` queue paused, then
# discards any ExecuteRoleJob instances that piled up during the pause before
# resuming. This isolates AIM from the live `bin/dev` Solid Queue worker: the
# seed and scenarios create tasks whose after_commit callbacks enqueue
# ExecuteRoleJobs for the assignee; without this, those would cascade into
# real agent runs that mutate state mid-test.
#
# The pause is a row in solid_queue_pauses, so it takes effect across every
# Rails process — including the nested `bin/director-mcp` instance that
# actually runs Task.create! inside create_task sub-agents.
#
# If the queue was already paused before we started (e.g. manual debugging),
# we leave it alone on the way out and skip job cleanup.
def with_execution_queue_paused
  queue = SolidQueue::Queue.new("execution")
  already_paused = queue.paused?
  queue.pause unless already_paused

  yield
ensure
  unless already_paused
    # Drop anything the cascade enqueued during the pause window. Without
    # this, resume would flush the backlog to the worker and the cascade
    # would happen anyway, just deferred.
    SolidQueue::Job.where(queue_name: "execution", finished_at: nil).destroy_all
    queue.resume
  end
end

namespace :aim do
  desc "Seed known data for AIM diagnostic scenarios"
  task seed: :environment do
    return unless Rails.env.development? || Rails.env.test?

    with_execution_queue_paused { AIMSeed.new.run }
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
    results = with_execution_queue_paused { runner.execute }

    # Print summary
    run_ok = results.count { |r| r.status == "success" }
    run_err = results.count { |r| r.status == "error" }
    passed = results.count { |r| r.verdict == "pass" }
    failed = results.count { |r| r.verdict == "fail" }
    total_cost = results.sum { |r| r.cost_cents || 0 }
    total_duration = results.sum { |r| r.duration_seconds || 0 }

    puts
    puts "=" * 60
    puts "AIM Results: #{passed} PASS / #{failed} FAIL / #{run_err} ERROR (#{results.size} total)"
    puts "  (runner: #{run_ok} ok, #{run_err} errored)"
    puts "Cost: $#{format('%.4f', total_cost / 100.0)} | Duration: #{total_duration.round(1)}s"
    puts "=" * 60

    results.each do |r|
      icon = case r.verdict
             when "pass" then "PASS"
             when "fail" then "FAIL"
             else "ERROR"
             end
      tools = r.tool_calls.map(&:tool).join(", ")
      puts "  [#{icon}] #{r.scenario_id} — tools: #{tools.presence || 'none'} (#{r.duration_seconds&.round(1)}s)"
      Array(r.assertion_failures).each { |f| puts "         - #{f}" }
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
        verdict: r.verdict,
        assertion_failures: r.assertion_failures,
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

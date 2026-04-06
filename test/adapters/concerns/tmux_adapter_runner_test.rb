require "test_helper"

# Unit tests for TmuxAdapterRunner in isolation. Uses a DummyTmuxAdapter that
# extends the module and implements the minimum hooks (build_agent_command,
# env_flags, parse_result), so we can exercise the shared tmux machinery
# without coupling to Claude or Opencode specifics.
class TmuxAdapterRunnerTest < ActiveSupport::TestCase
  # Captures every backtick shell-out for inspection. Tmux-based adapters use
  # backticks for `capture_pane` (and only there), so this narrowly targets
  # that single tmux invocation without stubbing the whole adapter class.
  module BacktickRecorder
    @@captured = []
    def self.captured; @@captured; end
    def self.reset!; @@captured = []; end
    def `(cmd)
      @@captured << cmd
      @@stub_output || ""
    end
    def self.stub_output=(val); @@stub_output = val; end
  end

  class DummyTmuxAdapter
    extend TmuxAdapterRunner

    SESSION_PREFIX = "dummy_runner"

    def self.build_agent_command(_role, _context, _temp_files)
      "echo hello"
    end

    def self.env_flags(_role)
      "-e FOO=bar"
    end

    # Default parse_result just returns the lines it was given so tests can
    # introspect what the module passed through.
    def self.parse_result(lines)
      { exit_code: 0, lines: lines }
    end
  end

  setup do
    # Every test stubs tmux primitives at the class level so we never shell out.
    @original = {}
    %i[poll_sleep spawn_session pane_alive? capture_pane kill_session].each do |m|
      if DummyTmuxAdapter.singleton_class.method_defined?(m, false)
        @original[m] = DummyTmuxAdapter.singleton_class.instance_method(m)
      end
    end

    @spawn_calls = []
    @kill_calls = []
    poll_count = 0

    DummyTmuxAdapter.define_singleton_method(:poll_sleep) { |_| nil }
    spawn_calls = @spawn_calls
    DummyTmuxAdapter.define_singleton_method(:spawn_session) { |cmd| spawn_calls << cmd; true }
    DummyTmuxAdapter.define_singleton_method(:pane_alive?) do |_|
      poll_count += 1
      poll_count <= 1
    end
    DummyTmuxAdapter.define_singleton_method(:capture_pane) { |_| "line1\nline2" }
    kill_calls = @kill_calls
    DummyTmuxAdapter.define_singleton_method(:kill_session) { |name| kill_calls << name; true }

    @role = roles(:cto)
    @role.define_singleton_method(:budget_exhausted?) { false }
    @run = RoleRun.create!(
      role: @role, task: tasks(:design_homepage), project: projects(:acme),
      status: :queued, trigger_type: "task_assigned"
    )
    @context = { run_id: @run.id }
  end

  teardown do
    %i[poll_sleep spawn_session pane_alive? capture_pane kill_session].each do |m|
      if (original = @original[m])
        DummyTmuxAdapter.singleton_class.define_method(m, original)
      elsif DummyTmuxAdapter.singleton_class.method_defined?(m, false)
        DummyTmuxAdapter.singleton_class.remove_method(m)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Bug fix: detached tmux pane geometry
  # ---------------------------------------------------------------------------

  test "spawn command sets -x PANE_WIDTH -y PANE_HEIGHT to prevent JSON line wrapping" do
    # Regression: without these flags tmux creates an 80x24 pane, long JSON
    # stream lines wrap, capture-pane returns fragments, JSON.parse skips them,
    # and parse_result raises the false-positive "exited without producing a
    # result" error. The user hit this on every run.
    DummyTmuxAdapter.execute_once(@role, @context)

    cmd = @spawn_calls.last
    assert_includes cmd, "-x #{TmuxAdapterRunner::PANE_WIDTH}",
      "spawn command should set wide pane: #{cmd}"
    assert_includes cmd, "-y #{TmuxAdapterRunner::PANE_HEIGHT}",
      "spawn command should set tall pane: #{cmd}"
  end

  test "PANE_WIDTH is large enough to fit a realistic stream-json event" do
    # Typical Claude `result` events are a few hundred bytes; `assistant` events
    # with large `thinking` signatures can be multi-KB. 500 comfortably covers
    # the common case and `-J` (below) covers anything longer.
    assert TmuxAdapterRunner::PANE_WIDTH >= 200,
      "PANE_WIDTH=#{TmuxAdapterRunner::PANE_WIDTH} is too narrow for typical JSON events"
  end

  test "capture_pane shells out with -J to rejoin wrapped lines" do
    # Belt-and-suspenders for the wide-pane fix: `-J` tells tmux to join any
    # visual rows that represent a single wrapped logical line back into one
    # line before returning them. Without this, a JSON line longer than the
    # pane width silently becomes invalid fragments.
    BacktickRecorder.reset!
    BacktickRecorder.stub_output = "dummy output"
    DummyTmuxAdapter.singleton_class.remove_method(:capture_pane) # un-stub
    DummyTmuxAdapter.singleton_class.prepend(BacktickRecorder)

    begin
      DummyTmuxAdapter.capture_pane("some_session")
    ensure
      # Re-stub so teardown's restore-or-remove flow cleans up correctly.
      DummyTmuxAdapter.define_singleton_method(:capture_pane) { |_| "" }
    end

    cmd = BacktickRecorder.captured.first
    assert_not_nil cmd, "capture_pane should have shelled out via backticks"
    assert_includes cmd, "tmux capture-pane"
    assert_includes cmd, " -J ", "capture-pane must include -J: #{cmd.inspect}"
    assert_includes cmd, " -p ", "capture-pane must include -p for printing"
    assert_includes cmd, " -S - ", "capture-pane must include -S - for full scrollback"
  end

  # ---------------------------------------------------------------------------
  # Happy path
  # ---------------------------------------------------------------------------

  test "execute_once spawns, polls, and returns parse_result output" do
    result = DummyTmuxAdapter.execute_once(@role, @context)

    assert_equal 0, result[:exit_code]
    assert_equal %w[line1 line2], result[:lines]
    assert_equal 1, @spawn_calls.size
  end

  test "execute_once wraps the agent command in a tempfile shell script" do
    # Writing to a tempfile (rather than passing the command inline) prevents
    # /bin/sh from re-interpreting backticks or $() inside prompt content as
    # command substitution.
    DummyTmuxAdapter.define_singleton_method(:build_agent_command) do |_r, _c, temp_files|
      "echo prompt-with-$(dangerous)-substitution"
    end
    DummyTmuxAdapter.execute_once(@role, @context)

    cmd = @spawn_calls.last
    assert_match %r{director_cmd\S*\.sh}, cmd,
      "spawn command should reference the tempfile script"
  end

  test "execute_once includes env_flags and session name" do
    DummyTmuxAdapter.execute_once(@role, @context)

    cmd = @spawn_calls.last
    assert_includes cmd, "-e FOO=bar"
    assert_includes cmd, "dummy_runner_#{@run.id}"
    assert_includes cmd, "remain-on-exit on"
  end

  test "execute_once cleans up tmux session in ensure" do
    DummyTmuxAdapter.define_singleton_method(:pane_alive?) { |_| raise RuntimeError, "boom" }

    assert_raises(RuntimeError) { DummyTmuxAdapter.execute_once(@role, @context) }

    assert_includes @kill_calls, "dummy_runner_#{@run.id}"
  end

  # ---------------------------------------------------------------------------
  # Budget / retry / stall
  # ---------------------------------------------------------------------------

  test "execute raises BudgetExhausted and never spawns when budget exhausted" do
    @role.define_singleton_method(:budget_exhausted?) { true }

    assert_raises(DummyTmuxAdapter::BudgetExhausted) do
      DummyTmuxAdapter.execute(@role, @context)
    end
    assert_empty @spawn_calls
  end

  test "BudgetExhausted constant on extending class is the same as the module class" do
    # Ensures `assert_raises(ClaudeLocalAdapter::BudgetExhausted)` in existing
    # tests still works after the refactor — the constant is aliased, not
    # re-defined, so `rescue` by class identity matches both.
    assert_equal TmuxAdapterRunner::BudgetExhausted, DummyTmuxAdapter::BudgetExhausted
    assert_equal TmuxAdapterRunner::ExecutionError, DummyTmuxAdapter::ExecutionError
  end

  test "execute retries once on retryable error then raises if still failing" do
    attempts = 0
    DummyTmuxAdapter.define_singleton_method(:spawn_session) do |_cmd|
      attempts += 1
      raise DummyTmuxAdapter::ExecutionError, "Agent stalled: no output"
    end

    assert_raises(DummyTmuxAdapter::ExecutionError) do
      DummyTmuxAdapter.execute(@role, @context)
    end
    assert_equal 2, attempts, "should attempt original + 1 retry = 2"
  end

  test "execute does not retry non-retryable errors" do
    attempts = 0
    DummyTmuxAdapter.define_singleton_method(:spawn_session) do |_cmd|
      attempts += 1
      raise DummyTmuxAdapter::ExecutionError, "tmux spawn failed: permission denied"
    end

    assert_raises(DummyTmuxAdapter::ExecutionError) do
      DummyTmuxAdapter.execute(@role, @context)
    end
    assert_equal 1, attempts, "non-retryable errors should not trigger retry"
  end

  test "retryable_error? matches stall and missing-result messages only" do
    assert DummyTmuxAdapter.retryable_error?(DummyTmuxAdapter::ExecutionError.new("Agent stalled: no output"))
    assert DummyTmuxAdapter.retryable_error?(DummyTmuxAdapter::ExecutionError.new("exited without producing a result"))
    assert_not DummyTmuxAdapter.retryable_error?(DummyTmuxAdapter::ExecutionError.new("tmux spawn failed"))
    assert_not DummyTmuxAdapter.retryable_error?(DummyTmuxAdapter::ExecutionError.new("connection refused"))
  end

  test "poll_session stall detection raises ExecutionError after STALL_TIMEOUT" do
    fake_now = Time.current
    original = Time.method(:current)
    Time.define_singleton_method(:current) { fake_now }

    begin
      DummyTmuxAdapter.define_singleton_method(:poll_sleep) do |_|
        fake_now += (TmuxAdapterRunner::STALL_TIMEOUT + 1)
      end
      DummyTmuxAdapter.define_singleton_method(:pane_alive?) { |_| true }
      DummyTmuxAdapter.define_singleton_method(:capture_pane) { |_| "same line" }

      error = assert_raises(DummyTmuxAdapter::ExecutionError) do
        DummyTmuxAdapter.poll_session("some_session", @run)
      end
      assert_match(/stalled/i, error.message)
    ensure
      Time.define_singleton_method(:current, original)
    end
  end

  # ---------------------------------------------------------------------------
  # Joined-line regression: prove parse_result sees whole JSON lines
  # ---------------------------------------------------------------------------

  test "joined long result line flows through to adapter parse_result unbroken" do
    # This is the core regression for the reported bug: a realistic-sized
    # `result` event (several hundred chars, longer than the old 80-col pane)
    # arrives as a single logical line because `-J` + wide pane guarantee it.
    # parse_result must receive that line intact so JSON.parse succeeds.
    long_result = '{"type":"result","subtype":"success","session_id":"ff79e460-8103-445e-ad1c-15cd497ced14","total_cost_usd":0.1696104,"result":"I have successfully completed the investigation of HorarioWebs language locale configuration with Spanish es as default Catalan ca and English en as supported languages configured in config application rb with all translation files present in config locales directory."}'
    DummyTmuxAdapter.define_singleton_method(:capture_pane) { |_| long_result }
    DummyTmuxAdapter.define_singleton_method(:parse_result) do |lines|
      parsed = lines.filter_map { |l| JSON.parse(l) rescue nil }
      { exit_code: 0, session_id: parsed.first&.dig("session_id") }
    end

    result = DummyTmuxAdapter.execute_once(@role, @context)

    assert_equal "ff79e460-8103-445e-ad1c-15cd497ced14", result[:session_id],
      "session_id must be extracted from a full-length result line"
  end

  # ---------------------------------------------------------------------------
  # Constants exposed on extending class
  # ---------------------------------------------------------------------------

  test "extending class inherits timing constants via const_set" do
    assert_equal 0.5, DummyTmuxAdapter::POLL_INTERVAL
    assert_equal 300, DummyTmuxAdapter::MAX_POLL_WAIT
    assert_equal 60,  DummyTmuxAdapter::STALL_TIMEOUT
    assert_equal 1,   DummyTmuxAdapter::STALL_RETRIES
  end
end

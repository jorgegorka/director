require "open3"
require "shellwords"
require "tempfile"

# Shared tmux-spawning machinery for local CLI adapters (ClaudeLocalAdapter,
# OpencodeAdapter, and any future tmux-based adapter).
#
# Adapters extend this module to gain the full spawn/poll/capture/cleanup flow,
# plus a default `execute` with budget check + retry. They implement three hooks:
#
#   - `build_agent_command(role, context, temp_files)` -> String
#       Returns the CLI invocation string to run inside the tmux pane.
#       The module wraps it in a tempfile shell script so backticks or $()
#       in prompts are not interpreted by /bin/sh as command substitution.
#
#   - `env_flags(role)` -> String
#       Returns `-e KEY=value` pairs for tmux new-session, adapter-specific
#       (different providers forward different credentials). Receives the
#       role so adapters can vary env based on `role.adapter_config` (e.g.
#       switching between hosted and Ollama providers).
#
#   - `parse_result(accumulated_lines)` -> Hash
#       Parses the stream output captured from tmux and returns an
#       `{ exit_code:, session_id:, cost_cents:, error_message: }` result.
#       Raises `ExecutionError, "... exited without producing a result"` when
#       the CLI finished without emitting its terminal result event (a genuine
#       failure mode — retryable via `retryable_error?`).
#
# Each extending class also defines its own `SESSION_PREFIX` constant for
# tmux session naming.
#
# Error classes and timing constants are exposed on the extending class via
# `const_set` in the `extended` hook, so existing references like
# `ClaudeLocalAdapter::ExecutionError` and `ClaudeLocalAdapter::STALL_TIMEOUT`
# continue to resolve unchanged.
module TmuxAdapterRunner
  # Error raised when the agent's budget is exhausted before execution starts.
  class BudgetExhausted < StandardError; end

  # Error raised when tmux spawn/capture fails or execution times out.
  class ExecutionError < StandardError; end

  POLL_INTERVAL = 0.5   # seconds between capture-pane polls
  MAX_POLL_WAIT = 300   # seconds, maximum time to poll before timeout (5 minutes)
  STALL_TIMEOUT = 60    # seconds without new output before declaring stall
  STALL_RETRIES = 1     # retry count for transient stall/crash errors

  # Pane geometry for detached tmux sessions.
  #
  # Without explicit sizing, `tmux new-session -d` creates an 80x24 pane.
  # Long JSON stream lines from CLI agents (thinking signatures, assistant
  # messages, result payloads — often several KB) then wrap to multiple visual
  # rows, and `tmux capture-pane` returns each wrapped row as a separate
  # "\n"-terminated line. `JSON.parse` in `parse_result` then skips every
  # fragment, no `result` event is matched, and the adapter raises the
  # misleading "Agent process exited without producing a result" error.
  #
  # -x 500 gives the pane enough width that realistic JSON lines do not wrap,
  # and `-J` on capture-pane (see `capture_pane`) rejoins any that still do.
  PANE_WIDTH  = 500
  PANE_HEIGHT = 50

  def self.extended(base)
    base.const_set(:BudgetExhausted, BudgetExhausted) unless base.const_defined?(:BudgetExhausted, false)
    base.const_set(:ExecutionError, ExecutionError) unless base.const_defined?(:ExecutionError, false)
    base.const_set(:POLL_INTERVAL, POLL_INTERVAL) unless base.const_defined?(:POLL_INTERVAL, false)
    base.const_set(:MAX_POLL_WAIT, MAX_POLL_WAIT) unless base.const_defined?(:MAX_POLL_WAIT, false)
    base.const_set(:STALL_TIMEOUT, STALL_TIMEOUT) unless base.const_defined?(:STALL_TIMEOUT, false)
    base.const_set(:STALL_RETRIES, STALL_RETRIES) unless base.const_defined?(:STALL_RETRIES, false)
  end

  # Default execute flow: budget check, then execute_once with retry on
  # transient errors (stalls, missing result events).
  def execute(role, context)
    if role.budget_exhausted?
      raise BudgetExhausted, "Role budget exhausted: spent #{role.monthly_spend_cents} of #{role.budget_cents} cents budget"
    end

    retries_remaining = STALL_RETRIES
    begin
      execute_once(role, context)
    rescue ExecutionError => e
      if retries_remaining > 0 && retryable_error?(e)
        retries_remaining -= 1
        retry
      end
      raise
    end
  end

  def execute_once(role, context)
    role_run     = RoleRun.find(context[:run_id])
    session_name = "#{self::SESSION_PREFIX}_#{context[:run_id]}"
    working_dir  = resolve_working_directory(role.effective_working_directory)
    temp_files   = []

    agent_cmd = build_agent_command(role, context, temp_files)

    # Write the agent command to a tempfile script so tmux executes it via
    # /bin/sh without the outer shell re-interpreting backticks or $() inside
    # prompt content. Both Claude (`-p <prompt>`) and Opencode
    # (`-p $(cat <file>)`) work correctly when sourced by /bin/sh this way.
    cmd_file = Tempfile.new([ "director_cmd", ".sh" ])
    cmd_file.write("#!/bin/sh\n#{agent_cmd}\n")
    cmd_file.flush
    cmd_file.chmod(0o755)
    temp_files << cmd_file

    spawn_cmd  = "tmux new-session -d -s #{session_name.shellescape}"
    spawn_cmd += " -x #{PANE_WIDTH} -y #{PANE_HEIGHT}"
    spawn_cmd += " -c #{working_dir.shellescape}" if working_dir.present?
    flags = env_flags(role)
    spawn_cmd += " #{flags}" if flags.present?
    spawn_cmd += " #{cmd_file.path.shellescape}"
    # remain-on-exit keeps the tmux pane alive after the command exits so we
    # can always capture output even if the process finishes quickly.
    spawn_cmd += " \\; set-option remain-on-exit on"

    kill_session(session_name)
    spawn_session(spawn_cmd)

    accumulated_lines = poll_session(session_name, role_run)
    parse_result(accumulated_lines)
  ensure
    cleanup_session(session_name) if defined?(session_name) && session_name
    temp_files&.each { |f| f.close! rescue nil }
  end

  def retryable_error?(error)
    error.message.match?(/stalled|exited without producing a result/i)
  end

  # Builds `-e KEY=value` flags from the current process ENV, skipping blanks
  # and shellescaping values. Shared by adapter `env_flags` implementations.
  def forward_env_flags(vars)
    vars.filter_map do |var|
      value = ENV[var]
      "-e #{var}=#{value.shellescape}" if value.present?
    end
  end

  # Overridable hook for poll sleep — enables zero-sleep in tests.
  def poll_sleep(seconds)
    sleep(seconds)
  end

  # Spawns a tmux session with the given command string.
  # Returns stdout on success, raises ExecutionError with stderr on failure.
  def spawn_session(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      raise ExecutionError, "tmux spawn failed: #{stderr.strip.presence || "unknown error (exit #{status.exitstatus})"}"
    end
    stdout
  end

  def session_exists?(name)
    system("tmux has-session -t #{name.shellescape} 2>/dev/null")
  end

  # Fails CLOSED on any unexpected tmux output so that an unreachable tmux
  # cannot keep a stuck run polling indefinitely.
  def pane_alive?(name)
    return false unless session_exists?(name)
    out, status = Open3.capture2("tmux", "display-message", "-t", name, "-p", '#{pane_dead}')
    return false unless status.success?
    out.strip == "0"
  end

  # Captures the current pane output from scrollback start.
  #
  # -J joins wrapped visual rows back into their original logical line. This is
  # the second half of the bug fix above (see PANE_WIDTH): even if some line
  # still exceeds the pane width, tmux reassembles it before we split on "\n",
  # so `JSON.parse` in `parse_result` sees a valid JSON line.
  def capture_pane(name)
    `tmux capture-pane -t #{name.shellescape} -p -J -S - 2>/dev/null`
  end

  def kill_session(name)
    system("tmux kill-session -t #{name.shellescape} 2>/dev/null")
  end

  def cleanup_session(name)
    kill_session(name)
  end

  def poll_session(session_name, role_run)
    last_line_count = 0
    accumulated_lines = []
    poll_count = 0
    max_polls = (MAX_POLL_WAIT / POLL_INTERVAL).to_i
    # Wall-clock, not CLOCK_MONOTONIC: monotonic pauses during host sleep on
    # macOS, which would silently disable stall detection on dev laptops.
    last_new_output_at = Time.current

    loop do
      output = capture_pane(session_name)
      lines = output.split("\n")

      if lines.size > last_line_count
        last_new_output_at = Time.current
        new_lines = lines[last_line_count..]
        new_lines.each do |line|
          role_run.broadcast_line!(line + "\n")
          accumulated_lines << line
        end
        last_line_count = lines.size
      end

      # With remain-on-exit the session stays alive after the process exits,
      # so we check pane_dead instead of session_exists. This guarantees we
      # capture all output before breaking.
      break unless pane_alive?(session_name)

      stall_elapsed = Time.current - last_new_output_at
      if stall_elapsed >= STALL_TIMEOUT
        kill_session(session_name)
        raise ExecutionError, "Agent stalled: no output for #{STALL_TIMEOUT} seconds"
      end

      poll_sleep(POLL_INTERVAL)

      poll_count += 1
      if poll_count >= max_polls
        kill_session(session_name)
        raise ExecutionError, "Execution timed out after #{MAX_POLL_WAIT} seconds"
      end
    end

    accumulated_lines
  end

  def resolve_working_directory(path)
    return nil if path.blank?

    resolved = File.realpath(path)
    unless File.directory?(resolved)
      raise ExecutionError, "Working directory is not a directory: #{path} (resolved to #{resolved})"
    end
    resolved
  rescue Errno::ENOENT
    raise ExecutionError, "Working directory does not exist: #{path}"
  end
end

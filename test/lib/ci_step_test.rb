require "test_helper"

# bin/ci is only read as text below: requiring it would run every CI step.
class CiStepTest < ActiveSupport::TestCase
  def build_step(warn_if: nil)
    Ci::Step.new(
      name: "some_step", label: "some step", blocking: true,
      command: "true", warn_if: warn_if, summarize: ->(log) { log }
    )
  end

  test "a step killed by a signal (no exit status) counts as failed instead of crashing bin/ci" do
    step = build_step
    assert_equal :fail, Ci::Step.status_for(step, exit_status: nil, log: "")
  end

  test "env defaults to an empty hash" do
    assert_equal({}, build_step.env)
  end

  test "exit 0 with no warn_if match is :ok" do
    step = build_step(warn_if: /NEVER_MATCHES/)
    assert_equal :ok, Ci::Step.status_for(step, exit_status: 0, log: "all good")
  end

  test "exit 0 with a warn_if match is :warn" do
    step = build_step(warn_if: /^System test budget .* — (NOTICE|WARN|OVER)/)
    log = "System test budget (ci): 130.0s — WARN 110s, fail 140s\n"
    assert_equal :warn, Ci::Step.status_for(step, exit_status: 0, log: log)
  end

  test "exit 0 with no warn_if configured at all is :ok" do
    step = build_step(warn_if: nil)
    assert_equal :ok, Ci::Step.status_for(step, exit_status: 0, log: "System test budget (ci): 200.0s — FAIL")
  end

  test "non-zero exit is :fail regardless of warn_if matching" do
    step = build_step(warn_if: /NEVER_MATCHES/)
    assert_equal :fail, Ci::Step.status_for(step, exit_status: 1, log: "boom")
  end

  test "non-zero exit is :fail even when warn_if would also match" do
    step = build_step(warn_if: /WARN/)
    assert_equal :fail, Ci::Step.status_for(step, exit_status: 1, log: "System test budget (ci): 200.0s — WARN")
  end
end

# bin/ci is never require'd (it runs the whole CI gauntlet at load time), so
# its rails_test_system step's env/warn_if wiring is checked as plain text.
class CiRailsTestSystemStepSourceTest < ActiveSupport::TestCase
  def step_source
    text = File.read(File.expand_path("../../bin/ci", __dir__))
    text[/Step\.new\(\s*name:\s*"rails_test_system".*?\n\s*\),?\n/m]
  end

  test "the rails_test_system step runs with PARALLEL_WORKERS=1 and SYSTEM_BUDGET=1" do
    source = step_source
    assert source, "expected a Step.new(name: \"rails_test_system\", ...) block in bin/ci"
    assert_match(/"PARALLEL_WORKERS"\s*=>\s*"1"/, source)
    assert_match(/"SYSTEM_BUDGET"\s*=>\s*"1"/, source)
  end

  test "the rails_test_system step's warn_if names NOTICE/WARN/OVER but not OK" do
    source = step_source
    warn_if_line = source[/warn_if:.*/]
    assert warn_if_line, "expected a warn_if: on the rails_test_system step"

    # Checked as text, not eval'd: the literal must name all three warn
    # statuses together so a status regex can't accidentally also match "OK".
    assert_match(/NOTICE/, warn_if_line)
    assert_match(/WARN/, warn_if_line)
    assert_match(/OVER/, warn_if_line)
    assert_no_match(/\bOK\b/, warn_if_line)
  end
end

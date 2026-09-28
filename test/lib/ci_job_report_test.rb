require "test_helper"
require "tmpdir"
require "fileutils"
require "yaml"

# Pins bin/ci-job-report's contract (plan-opus.md §2.4, tiers/behavior per
# §17.1 and §17.2). Runs it with a tmpdir as cwd (its own test/system_budget.yml,
# never the real repo's) since §17.2.2 says it resolves paths relative to cwd.
# JOB_START/JOB_NOW (§17.2.3) make the job total exactly controllable, so tier
# boundaries are asserted at the exact edges instead of with margins.
class CiJobReportTest < ActiveSupport::TestCase
  SCRIPT = File.expand_path("../../bin/ci-job-report", __dir__)
  JOB_START = 1_000_000_000.0
  OUTSIDE_STEPS_SECONDS = 3

  JOB_YAML = {
    "enforcement" => "warn",
    "job" => { "ideal_seconds" => 60, "notice_seconds" => 120, "warn_seconds" => 150, "fail_seconds" => 180, "outside_steps_seconds" => OUTSIDE_STEPS_SECONDS },
    "ci" => { "notice_seconds" => 80, "warn_seconds" => 110, "fail_seconds" => 140 },
    "local" => { "notice_seconds" => 90, "warn_seconds" => 123 }
  }.freeze

  def setup_project(enforcement: "warn")
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, "test"))
    FileUtils.mkdir_p(File.join(dir, "tmp"))
    File.write(File.join(dir, "test", "system_budget.yml"), JOB_YAML.merge("enforcement" => enforcement).to_yaml)
    dir
  end

  # total_seconds is the exact job total the report should compute:
  # (JOB_NOW - JOB_START) + outside_steps_seconds == total_seconds.
  def run_report(dir, total_seconds:)
    job_now = JOB_START + (total_seconds - OUTSIDE_STEPS_SECONDS)
    env = { "JOB_START" => JOB_START.to_s, "JOB_NOW" => job_now.to_s }
    out = IO.popen(env, [ "ruby", SCRIPT ], chdir: dir, err: [ :child, :out ], &:read)
    [ out, $?.exitstatus ]
  end

  test "reports 'no budget data' when tmp/system_budget.json is missing" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 10.0)
    assert_match(/no budget data/i, out)
    assert_equal 0, status
  end

  test "job total exactly at ideal (60) is not NOTICE/WARN/FAIL" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 60.0)
    assert_no_match(/\bNOTICE\b|\bWARN\b|\bFAIL\b/, out)
    assert_equal 0, status
  end

  test "job total at 60.01 is still not NOTICE (between ideal and notice)" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 60.01)
    assert_no_match(/\bNOTICE\b|\bWARN\b|\bFAIL\b/, out)
    assert_equal 0, status
  end

  test "job total exactly at 120 is still not NOTICE" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 120.0)
    assert_no_match(/\bNOTICE\b|\bWARN\b|\bFAIL\b/, out)
    assert_equal 0, status
  end

  test "job total at 120.01 is NOTICE" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 120.01)
    assert_match(/\bNOTICE\b/, out)
    assert_no_match(/\bWARN\b|\bFAIL\b/, out)
    assert_equal 0, status
  end

  test "job total exactly at 150 is still NOTICE, not WARN" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 150.0)
    assert_match(/\bNOTICE\b/, out)
    assert_no_match(/\bWARN\b|\bFAIL\b/, out)
    assert_equal 0, status
  end

  test "job total at 150.01 is WARN" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 150.01)
    assert_match(/\bWARN\b/, out)
    assert_no_match(/\bFAIL\b/, out)
    assert_equal 0, status
  end

  test "job total exactly at 180 is still WARN, not FAIL" do
    dir = setup_project
    out, status = run_report(dir, total_seconds: 180.0)
    assert_match(/\bWARN\b/, out)
    assert_no_match(/\bFAIL\b/, out)
    assert_equal 0, status
  end

  test "job total at 180.01 with enforcement fail is FAIL and exits 1" do
    dir = setup_project(enforcement: "fail")
    out, status = run_report(dir, total_seconds: 180.01)
    assert_match(/\bFAIL\b/, out)
    assert_equal 1, status
  end

  test "job total at 180.01 with enforcement warn is OVER (not enforced) and exits 0" do
    dir = setup_project(enforcement: "warn")
    out, status = run_report(dir, total_seconds: 180.01)
    assert_match(/OVER/, out)
    assert_equal 0, status
  end

  test "reports memory but never fails on it, even with a huge peak-baseline delta" do
    dir = setup_project(enforcement: "fail")
    FileUtils.mkdir_p(File.join(dir, "tmp", "ci_memory"))
    File.write(File.join(dir, "tmp", "ci_memory", "baseline_kb"), "100000")
    File.write(File.join(dir, "tmp", "ci_memory", "peak_kb"), "50000000")
    out, status = run_report(dir, total_seconds: 10.0) # comfortably under every tier
    assert_equal 0, status
    assert_match(/mi(b)?/i, out)
  end
end

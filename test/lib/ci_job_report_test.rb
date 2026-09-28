require "test_helper"
require "tmpdir"
require "fileutils"
require "yaml"

# Pins bin/ci-job-report's contract (plan-opus.md §2.4, tiers overridden by §17.1).
# The script has no path-injection env var in the spec, so these run it with a
# tmpdir as cwd (its own test/system_budget.yml, never the real repo's) and rely
# on it reading paths relative to the working directory, per "plain Ruby, no
# bundler". Exact job-total boundaries can't be hit precisely (wall-clock derived,
# no clock injection), so times are chosen with wide margins instead of testing
# the exact 60/120/150/180 edges.
class CiJobReportTest < ActiveSupport::TestCase
  SCRIPT = File.expand_path("../../bin/ci-job-report", __dir__)

  JOB_YAML = {
    "enforcement" => "warn",
    "job" => { "ideal_seconds" => 60, "notice_seconds" => 120, "warn_seconds" => 150, "fail_seconds" => 180, "outside_steps_seconds" => 3 },
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

  def run_report(dir, job_start_seconds_ago:)
    job_start = Time.now.to_i - job_start_seconds_ago
    out = IO.popen({ "JOB_START" => job_start.to_s }, [ "ruby", SCRIPT ], chdir: dir, err: [ :child, :out ], &:read)
    [ out, $?.exitstatus ]
  end

  test "reports 'no budget data' when tmp/system_budget.json is missing" do
    dir = setup_project
    out, status = run_report(dir, job_start_seconds_ago: 10)
    assert_match(/no budget data/i, out)
    assert_equal 0, status
  end

  test "exits 1 above the fail tier only when enforcement is fail" do
    dir = setup_project(enforcement: "fail")
    out, status = run_report(dir, job_start_seconds_ago: 200) # well over the 180s fail tier
    assert_equal 1, status
    assert_match(/error/i, out)
  end

  test "does not exit 1 above the fail tier when enforcement is warn" do
    dir = setup_project(enforcement: "warn")
    out, status = run_report(dir, job_start_seconds_ago: 200)
    assert_equal 0, status
    assert_match(/warning/i, out)
  end

  test "reports memory but never fails on it, even with a huge peak-baseline delta" do
    dir = setup_project(enforcement: "fail")
    FileUtils.mkdir_p(File.join(dir, "tmp", "ci_memory"))
    File.write(File.join(dir, "tmp", "ci_memory", "baseline_kb"), "100000")
    File.write(File.join(dir, "tmp", "ci_memory", "peak_kb"), "50000000")
    out, status = run_report(dir, job_start_seconds_ago: 10) # comfortably under every tier
    assert_equal 0, status
    assert_match(/mi(b)?/i, out)
  end
end

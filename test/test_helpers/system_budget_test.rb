require "test_helper"
require "tmpdir"

# Config comes from a tmpdir file on every call, never test/system_budget.yml.
class SystemBudgetTest < ActiveSupport::TestCase
  CI_CONFIG = {
    enforcement: "warn",
    job: { ideal_seconds: 60, notice_seconds: 120, warn_seconds: 150, fail_seconds: 180, outside_steps_seconds: 3 },
    ci: { notice_seconds: 80, warn_seconds: 110, fail_seconds: 140 },
    local: { notice_seconds: 90, warn_seconds: 123 }
  }.freeze

  def write_yaml(hash)
    path = File.join(Dir.mktmpdir, "system_budget.yml")
    File.write(path, hash.to_yaml)
    path
  end

  # --- 1. Config loading fails loudly ---

  test "load_config raises for a missing file" do
    assert_raises(SystemBudget::ConfigError) do
      SystemBudget.load_config(File.join(Dir.mktmpdir, "does_not_exist.yml"))
    end
  end

  test "load_config raises for malformed yaml" do
    path = File.join(Dir.mktmpdir, "system_budget.yml")
    File.write(path, "enforcement: [unterminated")
    assert_raises(SystemBudget::ConfigError) { SystemBudget.load_config(path) }
  end

  test "load_config raises when required keys are missing" do
    path = write_yaml(enforcement: "warn", job: { ideal_seconds: 60 })
    assert_raises(SystemBudget::ConfigError) { SystemBudget.load_config(path) }
  end

  # --- 1. Tier classification, CI profile, enforcement: warn ---

  test "ci profile: exactly at notice is OK" do
    assert_equal :ok, SystemBudget.status_for(80.0, profile: :ci, config: CI_CONFIG, enforcement: :warn)
  end

  test "ci profile: notice + 0.01 is NOTICE" do
    assert_equal :notice, SystemBudget.status_for(80.01, profile: :ci, config: CI_CONFIG, enforcement: :warn)
  end

  test "ci profile: exactly at warn is still NOTICE" do
    assert_equal :notice, SystemBudget.status_for(110.0, profile: :ci, config: CI_CONFIG, enforcement: :warn)
  end

  test "ci profile: warn + 0.01 is WARN" do
    assert_equal :warn, SystemBudget.status_for(110.01, profile: :ci, config: CI_CONFIG, enforcement: :warn)
  end

  test "ci profile: exactly at fail is still WARN" do
    assert_equal :warn, SystemBudget.status_for(140.0, profile: :ci, config: CI_CONFIG, enforcement: :warn)
  end

  test "ci profile, enforcement warn: fail + 0.01 is OVER, not enforced" do
    assert_equal :over, SystemBudget.status_for(140.01, profile: :ci, config: CI_CONFIG, enforcement: :warn)
  end

  test "ci profile, enforcement fail: fail + 0.01 is FAIL" do
    assert_equal :fail, SystemBudget.status_for(140.01, profile: :ci, config: CI_CONFIG, enforcement: :fail)
  end

  # --- 1. Tier classification, local profile: never FAIL/OVER ---

  test "local profile: exactly at notice is OK" do
    assert_equal :ok, SystemBudget.status_for(90.0, profile: :local, config: CI_CONFIG, enforcement: :warn)
  end

  test "local profile: notice + 0.01 is NOTICE" do
    assert_equal :notice, SystemBudget.status_for(90.01, profile: :local, config: CI_CONFIG, enforcement: :warn)
  end

  test "local profile: warn + 0.01 is WARN" do
    assert_equal :warn, SystemBudget.status_for(123.01, profile: :local, config: CI_CONFIG, enforcement: :warn)
  end

  test "local profile stays WARN far above warn, even with enforcement fail" do
    assert_equal :warn, SystemBudget.status_for(10_000.0, profile: :local, config: CI_CONFIG, enforcement: :fail)
  end

  # --- 2. Output shape ---

  test "first line matches the exact specified shape" do
    records = [ { name: "FooTest#test_a", seconds: 3.0 } ]
    report = SystemBudget.format_report(profile: :ci, config: CI_CONFIG, enforcement: :warn, records: records, retried: [])
    first_line = report.lines.first.chomp
    assert_match(/\ASystem test budget \(ci\): 3\.0s — /, first_line)
  end

  test "slowest list has at most 10 entries in descending order" do
    records = (1..12).map { |i| { name: "Test#n#{i}", seconds: i.to_f } }
    report = SystemBudget.format_report(profile: :ci, config: CI_CONFIG, enforcement: :warn, records: records, retried: [])
    slowest_lines = report.lines.grep(/\d+\.\d+s Test#/)
    assert_equal 10, slowest_lines.length
    times = slowest_lines.map { |l| l[/(\d+\.\d+)s/, 1].to_f }
    assert_equal times.sort.reverse, times
  end

  test "retried tests are listed with their extra seconds" do
    records = [ { name: "NoteConflictTest#test_x", seconds: 6.12 } ]
    retried = [ { name: "NoteConflictTest#test_x", extra_seconds: 4.2 } ]
    report = SystemBudget.format_report(profile: :ci, config: CI_CONFIG, enforcement: :warn, records: records, retried: retried)
    assert_match(/retried: 1 \(NoteConflictTest#test_x, 4\.2s extra\)/, report)
  end

  test "no retries reports 'retried: none'" do
    records = [ { name: "FooTest#test_a", seconds: 1.0 } ]
    report = SystemBudget.format_report(profile: :ci, config: CI_CONFIG, enforcement: :warn, records: records, retried: [])
    assert_match(/retried: none/, report)
  end

  # --- 3. Retries counted in the total ---

  test "a retried test's full wall time (spanning every attempt) counts toward the total" do
    records = [
      { name: "NoteConflictTest#test_x", seconds: 6.12 }, # one record already spans both attempts
      { name: "OtherTest#test_y", seconds: 2.0 }
    ]
    retried = [ { name: "NoteConflictTest#test_x", extra_seconds: 4.2 } ]
    report = SystemBudget.format_report(profile: :ci, config: CI_CONFIG, enforcement: :warn, records: records, retried: retried)
    assert_match(/\ASystem test budget \(ci\): 8\.12?s — /, report.lines.first)
  end

  # --- 4. Serial guard ---

  test "PARALLEL_WORKERS != 1 fails the gate in CI enforcement fail mode" do
    status = SystemBudget.status_for(1.0, profile: :ci, config: CI_CONFIG, enforcement: :fail, parallel_workers: "4")
    assert_equal :fail, status
  end

  test "PARALLEL_WORKERS != 1 only warns in CI enforcement warn mode" do
    status = SystemBudget.status_for(1.0, profile: :ci, config: CI_CONFIG, enforcement: :warn, parallel_workers: "4")
    assert_equal :warn, status
  end

  test "the serial guard message names PARALLEL_WORKERS=1" do
    report = SystemBudget.format_report(
      profile: :ci, config: CI_CONFIG, enforcement: :fail,
      records: [ { name: "FooTest#test_a", seconds: 1.0 } ], retried: [], parallel_workers: "4"
    )
    assert_match(/PARALLEL_WORKERS=1/, report)
  end
end

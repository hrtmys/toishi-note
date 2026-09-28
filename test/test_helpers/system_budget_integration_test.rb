require "test_helper"
require "tmpdir"
require "open3"
require "json"

# Runs a real Minitest process with the gate installed, since the unit tests
# never prove the plugin is registered or that fail mode fails the run.
class SystemBudgetIntegrationTest < ActiveSupport::TestCase
  PROBE = <<~RUBY
    require File.expand_path("test/test_helper", ENV.fetch("APP_ROOT"))

    class BudgetProbeTest < ActiveSupport::TestCase
      test "takes measurable time" do
        sleep 0.05
        assert true
      end
    end

    SystemBudget.install!(test_case: BudgetProbeTest, config_path: ENV.fetch("BUDGET_CONFIG"))
  RUBY

  def run_probe(enforcement:)
    dir = Dir.mktmpdir
    config = {
      enforcement: enforcement,
      job: { ideal_seconds: 60, notice_seconds: 120, warn_seconds: 150, fail_seconds: 180, outside_steps_seconds: 3 },
      ci: { notice_seconds: 0.001, warn_seconds: 0.002, fail_seconds: 0.01 },
      local: { notice_seconds: 90, warn_seconds: 123 }
    }
    File.write(File.join(dir, "system_budget.yml"), config.deep_stringify_keys.to_yaml)
    File.write(File.join(dir, "probe_test.rb"), PROBE)
    env = { "APP_ROOT" => Rails.root.to_s, "BUDGET_CONFIG" => File.join(dir, "system_budget.yml"),
            "CI" => "1", "PARALLEL_WORKERS" => "1", "RAILS_ENV" => "test", "GITHUB_STEP_SUMMARY" => nil }
    output, status = Open3.capture2e(env, RbConfig.ruby, File.join(dir, "probe_test.rb"), chdir: Rails.root.to_s)
    [ output, status ]
  end

  test "fail mode over the fail tier makes the whole test run exit non-zero, even though every test passed" do
    output, status = run_probe(enforcement: "fail")

    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors/, output)
    assert_match(/^System test budget \(ci\): .* FAIL$/, output)
    assert_match(/^::error title=System test budget::/, output)
    assert_not status.success?, "a FAIL budget must fail the run:\n#{output}"
  end

  test "warn mode over the fail tier reports OVER but lets the run pass" do
    output, status = run_probe(enforcement: "warn")

    assert_match(/^System test budget \(ci\): .* OVER \(not enforced\)$/, output)
    assert_match(/^::warning title=System test budget::/, output)
    assert status.success?, "warn mode must not fail the run:\n#{output}"
  end

  test "the run's JSON record carries the totals and every threshold it was judged against" do
    run_probe(enforcement: "warn")
    data = JSON.parse(File.read(Rails.root.join("tmp/system_budget.json")))

    %w[profile enforcement total_seconds suite_wall_seconds notice_seconds warn_seconds fail_seconds
       status tests slowest retried].each do |key|
      assert data.key?(key), "tmp/system_budget.json is missing #{key}: #{data.keys}"
    end
    assert_equal "ci", data["profile"]
    assert_equal 1, data["tests"]
    assert_operator data["total_seconds"], :>=, 0.05
    assert_equal 0.01, data["fail_seconds"]
  end
end

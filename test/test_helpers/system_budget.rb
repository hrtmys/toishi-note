require "yaml"

# Times each system test and reports the total against test/system_budget.yml.
module SystemBudget
  class ConfigError < StandardError; end

  REQUIRED_JOB_KEYS = %i[ideal_seconds notice_seconds warn_seconds fail_seconds outside_steps_seconds].freeze
  REQUIRED_CI_KEYS = %i[notice_seconds warn_seconds fail_seconds].freeze
  REQUIRED_LOCAL_KEYS = %i[notice_seconds warn_seconds].freeze

  STATUS_WORDS = {
    ok: "OK", notice: "NOTICE", warn: "WARN", fail: "FAIL", over: "OVER (not enforced)"
  }.freeze

  class << self
    def default_config_path
      Rails.root.join("test/system_budget.yml")
    end

    def load_config(path = default_config_path)
      raise ConfigError, "system budget config not found: #{path}" unless File.exist?(path)

      config = YAML.safe_load(File.read(path), symbolize_names: true)
      validate!(config, path)
      config
    rescue Psych::Exception => e
      raise ConfigError, "malformed system budget config at #{path}: #{e.message}"
    end

    def status_for(seconds, profile:, config:, enforcement:, parallel_workers: "1")
      band = tiers(config, profile)
      serial_broken = parallel_workers.to_s != "1"

      if profile == :local
        return :warn if serial_broken || seconds > band.fetch(:warn_seconds)
        return :notice if seconds > band.fetch(:notice_seconds)

        :ok
      else
        return (enforcement == :fail ? :fail : :warn) if serial_broken
        return (enforcement == :fail ? :fail : :over) if seconds > band.fetch(:fail_seconds)
        return :warn if seconds > band.fetch(:warn_seconds)
        return :notice if seconds > band.fetch(:notice_seconds)

        :ok
      end
    end

    def format_report(profile:, config:, enforcement:, records:, retried:, parallel_workers: "1")
      band = tiers(config, profile)
      total = records.sum { |r| r[:seconds] }.round(1)
      status = status_for(total, profile: profile, config: config, enforcement: enforcement, parallel_workers: parallel_workers)

      lines = []
      lines << "System test budget (#{profile}): #{total}s — #{threshold_text(band, profile)} — #{STATUS_WORDS.fetch(status)}"
      lines << "  #{records.size} tests"
      lines << "  slowest:"
      records.sort_by { |r| -r[:seconds] }.first(10).each do |r|
        lines << format("    %5.2fs %s", r[:seconds], r[:name])
      end
      lines << retried_line(retried)
      lines << serial_guard_line(enforcement) if parallel_workers.to_s != "1"

      "#{lines.join("\n")}\n"
    end

    # Installed from test/application_system_test_case.rb, only when
    # ENV["SYSTEM_BUDGET"] == "1" — a scoped `bin/rails test test/system/x`
    # run stays quiet.
    def install!(test_case:, config_path: default_config_path, io: $stdout)
      config = load_config(config_path)
      enforcement = config.fetch(:enforcement).to_sym
      profile = ENV["CI"] ? :ci : :local
      parallel_workers = ENV["PARALLEL_WORKERS"] || "1"

      records = []
      retried = []

      timing = Module.new do
        define_method(:run) do
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super()
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
          records << { name: "#{self.class}##{name}", seconds: elapsed.round(2) }
          result
        end
      end
      test_case.prepend(timing)

      if defined?(Minitest::Retry) && Minitest::Retry.retry_count.to_i > 0
        Minitest::Retry.on_retry do |klass, meth, _count, result|
          retried << { name: "#{klass}##{meth}", extra_seconds: result.time.to_f.round(2) }
        end
      end

      Minitest.register_plugin(Plugin.build(config: config, enforcement: enforcement, profile: profile,
                                             parallel_workers: parallel_workers, records: records, retried: retried, io: io))
    end

    private

    def tiers(config, profile)
      profile == :local ? config.fetch(:local) : config.fetch(:ci)
    end

    def threshold_text(band, profile)
      if profile == :local
        "notice #{band[:notice_seconds]}s, warn #{band[:warn_seconds]}s"
      else
        "notice #{band[:notice_seconds]}s, warn #{band[:warn_seconds]}s, fail #{band[:fail_seconds]}s"
      end
    end

    def retried_line(retried)
      return "  retried: none" if retried.empty?

      detail = retried.map { |r| "#{r[:name]}, #{r[:extra_seconds]}s extra" }.join("; ")
      "  retried: #{retried.size} (#{detail})"
    end

    def serial_guard_line(enforcement)
      prefix = enforcement == :fail ? "FAIL" : "WARNING"
      "  #{prefix}: budget gate needs PARALLEL_WORKERS=1"
    end

    def validate!(config, path)
      ok = config.is_a?(Hash) && config[:enforcement] &&
        REQUIRED_JOB_KEYS.all? { |k| config.dig(:job, k) } &&
        REQUIRED_CI_KEYS.all? { |k| config.dig(:ci, k) } &&
        REQUIRED_LOCAL_KEYS.all? { |k| config.dig(:local, k) }
      raise ConfigError, "system budget config missing required keys: #{path}" unless ok
    end
  end

  # Minitest 6's register_plugin takes only a symbol, string, or Module, so
  # each install! builds a fresh Module that closes over this run's state.
  module Plugin
    def self.build(config:, enforcement:, profile:, parallel_workers:, records:, retried:, io:)
      Module.new do
        state = { config: config, enforcement: enforcement, profile: profile,
                   parallel_workers: parallel_workers, records: records, retried: retried, io: io }
        define_singleton_method(:minitest_plugin_init) do |_options|
          Minitest.reporter << Reporter.new(**state)
        end
      end
    end
  end

  class Reporter < Minitest::AbstractReporter
    def initialize(config:, enforcement:, profile:, parallel_workers:, records:, retried:, io:)
      super()
      @config = config
      @enforcement = enforcement
      @profile = profile
      @parallel_workers = parallel_workers
      @records = records
      @retried = retried
      @io = io
    end

    def report
      @status = SystemBudget.status_for(total_seconds, profile: @profile, config: @config,
                                         enforcement: @enforcement, parallel_workers: @parallel_workers)
      text = SystemBudget.format_report(profile: @profile, config: @config, enforcement: @enforcement,
                                         records: @records, retried: @retried, parallel_workers: @parallel_workers)
      @io.puts text

      return unless ENV["CI"]

      first_line = text.lines.first.chomp
      case @status
      when :notice then @io.puts "::notice title=System test budget::#{first_line}"
      when :warn, :over then @io.puts "::warning title=System test budget::#{first_line}"
      when :fail then @io.puts "::error title=System test budget::#{first_line}"
      end

      if (summary_path = ENV["GITHUB_STEP_SUMMARY"])
        File.open(summary_path, "a") { |f| f.puts("## System test budget\n\n```\n#{text}```\n") }
      end

      write_json
    end

    def passed?
      @status != :fail
    end

    private

    def total_seconds
      @records.sum { |r| r[:seconds] }.round(1)
    end

    def write_json
      require "json"
      require "fileutils"
      FileUtils.mkdir_p(Rails.root.join("tmp"))
      File.write(Rails.root.join("tmp/system_budget.json"), {
        profile: @profile, enforcement: @enforcement, total_seconds: total_seconds,
        status: @status.to_s, tests: @records.size,
        slowest: @records.sort_by { |r| -r[:seconds] }.first(10),
        retried: @retried
      }.to_json)
    end
  end
end

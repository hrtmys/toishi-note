module Ci
  # Lives outside bin/ci so tests can require it: loading bin/ci runs every step.
  class Step < Struct.new(:name, :label, :blocking, :command, :env, :warn_if, :summarize, keyword_init: true)
    def initialize(**attrs)
      super(**{ env: {} }.merge(attrs))
    end

    # bin/ci downgrades a non-blocking step's :fail to :warn itself; warn_if lets
    # a passing step (the system test budget) still show as :warn.
    def self.status_for(step, exit_status:, log:)
      return :fail unless exit_status.zero?
      return :warn if step.warn_if && step.warn_if.match?(log)

      :ok
    end
  end
end

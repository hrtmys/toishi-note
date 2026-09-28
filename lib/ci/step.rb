module Ci
  # A single bin/ci step (plan-opus.md §17.2.4). Extracted so the status
  # decision is requirable — and testable — without loading bin/ci itself,
  # which runs the whole CI gauntlet at require time.
  class Step < Struct.new(:name, :label, :blocking, :command, :env, :warn_if, :summarize, keyword_init: true)
    def initialize(**attrs)
      super(**{ env: {} }.merge(attrs))
    end

    # A blocking step's non-zero exit is always :fail; a non-blocking
    # step's non-zero exit is left to the caller (bin/ci treats it as
    # :warn). Success can still downgrade to :warn via warn_if, e.g. the
    # system test budget gate.
    def self.status_for(step, exit_status:, log:)
      return :fail unless exit_status.zero?
      return :warn if step.warn_if && step.warn_if.match?(log)

      :ok
    end
  end
end

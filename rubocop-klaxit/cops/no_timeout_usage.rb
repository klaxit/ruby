# frozen_string_literal: true

module RuboCop
  module Cop
    # Using Timeout.timeout is dangerous. We add a cop to detect
    # Timeout.timeout calls.
    # See: https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/
    class NoTimeoutUsage < Cop
      MSG = "Timeout is dangerous, do NOT use it. Please refer to: "\
            "https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/"

      # Add offense if timeout usage
      def on_send(node)
        return unless timeout_call?(node)

        add_offense(node)
      end

      def_node_matcher :timeout_call?, <<~PATTERN
        (send
          (const nil? :Timeout) :timeout ...)
      PATTERN
    end
  end
end

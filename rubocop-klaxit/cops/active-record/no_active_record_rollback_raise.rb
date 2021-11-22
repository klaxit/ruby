# frozen_string_literal: true

module RuboCop
  module Cop
    module ActiveRecord
      class NoActiveRecordRollbackRaise < Cop
        MSG = "Avoid raising `ActiveRecord::Rollback`"
        RESTRICT_ON_SEND = %i(raise fail).freeze

        def_node_matcher :ar_rollback_raise?, <<~PATTERN
          (send nil? {:raise :fail}
            (const
              (const nil? :ActiveRecord) :Rollback)
                ...)
        PATTERN

        # :nodoc:
        def on_send(node)
          return unless ar_rollback_raise?(node)

          add_offense(node)
        end
      end
    end
  end
end

# frozen_string_literal: true

module RuboCop
  module Cop
    module ActiveRecord
      # Ensure migrations which add indexes are always outside transactions
      # with disable_ddl_transaction!
      class NoTransactionOnAddIndexMigration < Cop
        MSG = "Migrations which add indexes should not be in transactions"

        def_node_matcher :is_migration?, <<~PATTERN
          (class _ `(const (const nil? :ActiveRecord) :Migration) _)
        PATTERN

        def_node_search :has_send_with_sym?, <<~PATTERN
          (send nil? %1 ...)
        PATTERN

        def on_class(node)
          return unless is_migration?(node) &&
                        has_send_with_sym?(node, :add_index)
          return if has_send_with_sym?(node, :disable_ddl_transaction!)

          add_offense(node)
        end
      end
    end
  end
end

# frozen_string_literal: true

module RuboCop
  module Cop
    # Cop that makes sure low queue is specify in worker call.
    class SpecifyLowQueueInMigration < RuboCop::Cop::Cop
      MSG = "Specify low queue when you call worker in migration with " \
            "'HardWorker.set(queue: :app_name_low).perform_async(args)' " \
            "or MyClass.delay(queue: 'app_name_low').some_method(1, 2, 3)"

      def on_send(node)
        return nil unless in_migration?(node)
        #  || sidekiq_push?(node)
        return unless sidekiq_called?(node)
        return if low_queue_specify?(node)

        add_offense(node.arguments.first, location: :expression)
      end

      def sidekiq_called?(node)
        worker_called?(node) ||
          sidekiq_delay?(node) ||
          sidekiq_client_called?(node)
      end

      def low_queue_specify?(node)
        low_queue_specify_for_perform?(node) ||
          low_queue_specify_for_delay?(node) ||
          low_queue_specify_for_push?(node)
      end

      def in_migration?(node)
        dirname = File.dirname(node.location.expression.source_buffer.name)
        dirname.end_with?("db/migrate", "db/geo/migrate") ||
          in_post_deployment_migration?(node)
      end

      def_node_matcher :worker_called?, <<~PATTERN
        (send (...) {:perform_async :perform_in :perform_at} ...)
      PATTERN

      def_node_matcher :sidekiq_delay?, <<~PATTERN
        (send (send (...) {:delay :delay_for :delay_until} ...) ... (...))
      PATTERN

      def_node_matcher :sidekiq_push?, <<~PATTERN
        (send (const (const nil? :Sidekiq) :Client) :push ...)
      PATTERN

      def_node_matcher :sidekiq_client_called?, <<~PATTERN
        (send (const (const nil? :Sidekiq) :Client) :push ...)
      PATTERN

      def_node_matcher :low_queue_specify_for_perform?, <<~PATTERN
        (send (send (...) :set (hash (pair (sym :queue) (...))))
        {:perform_async :perform_in :perform_at} ...)
      PATTERN

      def_node_matcher :low_queue_specify_for_delay?, <<~PATTERN
        (send (send (...) {:delay :delay_for :delay_until}
        (hash (pair (sym :queue) (...)))) ... (...))
      PATTERN

      def_node_matcher :low_queue_specify_for_push?, <<~PATTERN
        (send (const (const nil? :Sidekiq) :Client) :push
        (hash (pair (str "class") (...))
              (pair (str "args") (...))
              (pair (str "queue") (...)))
        )
      PATTERN
    end
  end
end

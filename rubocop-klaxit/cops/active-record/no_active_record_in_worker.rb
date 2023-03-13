# frozen_string_literal: true

module RuboCop
  module Cop
    module ActiveRecord
      # Forbids `call_async` when one of the attributes
      # is an ActiveRecord object
      #
      # Those objects can introduce side effects, since due
      # to the async nature of workers,
      # the active record object can have changed when the worker is run
      #
      # # Bad
      # class Mate < AppRecord; end
      #
      # class ZendeskCreateTicketBad < Service
      #   attribute :mate,              Types.Instance(Mate)
      # end
      #
      # ZendeskCreateTicketBad.call_async(mate: …)
      #
      # #
      # +
      # class ZendeskCreateTicketGood < Service
      #   attribute :mate_id,  Types::Strict::Integer
      # end
      # ZendeskCreateTicketGood.call_async(mate_id: 123)
      class NoActiveRecordInWorker < Cop
        MSG = "Avoid ActiveRecord objects in `call_async` calls."\
            "Prefer object ids in order to avoid concurrency"\
            "issues or side effects"

        RESTRICT_ON_SEND = %i(call_async).freeze

        # :nodoc:
        def on_send(node)
          # return nil unless in_worker?(node)
          # return unless attribute_called?(node)

          # https://stackoverflow.com/a/61333794
          # https://dmytrovasin.medium.com/how-to-add-a-custom-cop-to-rubocop-47abf82f820a
          # node.arguments.each do |arg|
          #   arg
          # end
          # add_offense(node)
        end

        def in_worker?(node)
          # useless, we want to catch all call_async calls
          # return true
          # dirname = File.dirname(node.location.expression.source_buffer.name)
          # dirname.include?("app/workers")
        end
      end
    end
  end
end

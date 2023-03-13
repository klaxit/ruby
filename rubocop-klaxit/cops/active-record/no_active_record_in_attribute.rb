# frozen_string_literal: true

module RuboCop
  module Cop
    module ActiveRecord
      # # Bad
      # class Mate < AppRecord; end
      #
      # class ZendeskCreateTicketBad < Worker
      #   attribute :mate,              Types.Instance(Mate)
      # end
      #
      # ZendeskCreateTicketBad.call_async(mate: …)
      #
      # #
      # +
      # class ZendeskCreateTicketGood < Worker
      #   attribute :mate_id,  Types::Strict::Integer
      # end
      # ZendeskCreateTicketGood.call_async(mate_id: 123)
      class NoActiveRecordInAttribute < Cop
        MSG = "Avoid ActiveRecord objects in `attributes` for workers"

        RESTRICT_ON_SEND = %i(attribute).freeze

        def_node_matcher :is_types_instance?, <<~PATTERN
        (send nil :attribute
          (sym :mate)
          (send
            (const nil :Types) :Instance
            $(...)))
        PATTERN

        # :nodoc:
        def on_send(node)
          # puts node
          pattern = <<~PATTERN
            (send nil :attribute
              (sym :mate)
              (send
                (const nil :Types) :Instance
                (const nil :Mate)))
          PATTERN
          if NodePattern.new(pattern).match(node)
            puts "match"
          else
            puts "no match"
            puts node
          end


          puts is_types_instance?(node)

          # is_types_instance?(node) do |arg|
          #   puts "yea"
          #   puts arg
          # end
          # puts(node.parent.class) #if is_types_instance?(node.last_argument)
          # puts(node.last_argument) #if is_types_instance?(node.last_argument)
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

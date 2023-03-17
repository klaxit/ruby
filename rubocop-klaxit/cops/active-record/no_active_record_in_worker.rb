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
      # # Good
      # class ZendeskCreateTicketGood < Service
      #   attribute :mate_id,  Types::Strict::Integer
      # end
      # ZendeskCreateTicketGood.call_async(mate_id: 123)
      class NoActiveRecordInWorker < Cop
        MSG = "Avoid ActiveRecord objects in `call_async` calls." \
              "Prefer object ids in order to avoid concurrency" \
              "issues or side effects"

        RESTRICT_ON_SEND = %i(call_async).freeze

        # :nodoc:
        def on_send(node)
          puts node
          service_name = node.receiver.short_name
          return unless is_service_blacklisted?(service_name)
          add_offense(node)
        end

        def_node_matcher :is_sent_call_async?, <<~PATTERN
          (send ... {:perform_async :call_async} ...)
        PATTERN

        private

        # returns true if the service in the following file contains
        # attributes from our blacklist
        def is_service_blacklisted?(service_name)
          # It should be possible to navigate the service class AST and find the calls to
          # attribute (eg "attribute :booking, Types.Instance(Booking)")
          # using RuboCop AST navigagtion, but I didn’t get it to work
          # processed_source = RuboCop::ProcessedSource.new(source, ruby_version, nil)
          # processed_source.ast
          #
          # def_node_search :attribute_calls, <<~PATTERN
          #     (send (const nil :Types) :Instance ...)
          # PATTERN
          # Alternative solution: use regex
          source_file = "app/services/#{service_name}.rb"
          return false unless File.exist?(source_file)

          source = File.read(source_file)
          attribute_instances = source.scan(/attribute.*Types.Instance\((.*)\)/).flatten
          (attribute_instances & model_blacklist).size > 0
        end

        # returns a list of all the Models we want to avoid having as part of the attribute
        def model_blacklist
          list_all_models
        end

        # Turn "ActivateAdministrator" into "activate_administrator"
        # so that we can reach the require source file from a service name
        def service_to_file(name)
          word = name.dup
          word.gsub!(/::/, "/")
          word.gsub!(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
          word.tr!("-", "_")
          word.downcase!
        end

        # list all the files in app/models and turn the
        # file names into class names ;
        # 'app/models/stripe_event.rb' becomes StripeEvent
        def list_all_models
          return [] unless Dir.exist?("./app/models")
          Dir.glob("./app/models/*")
             .select { |f| File.file?(f) }
             .map do |model_path|
            File.basename(model_path)
                .sub(/\.rb$/, "")
                .split("_")
                .map(&:capitalize)
                .join
          end
        end
      end
    end
  end
end

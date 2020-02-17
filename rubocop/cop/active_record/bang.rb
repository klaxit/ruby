# frozen_string_literal: true

module RuboCop
  module Cop
    module ActiveRecord
      class Bang < RuboCop::Cop::Cop
        PATTERN = "(send _ #bang_method? ...)"

        METHODS = {
          update_attributes: "{lvar hash}",
          update: "{lvar hash}",
          create: "{lvar hash} ?",
          save: "{lvar hash} ?",
          decrement: "{str sym lvar} {int lvar}",
          destroy: "",
          toogle: "{str sym lvar}",
          becomes: "{const lvar}"
        }.map do |method, arguments|
          [
            method,
            NodePattern.new(
              PATTERN.sub("#bang_method?", ":#{method}")
                     .sub("...", arguments)
            )
          ]
        end.to_h.freeze

        MSG = "Prefer the use of the bang method '%s!'. " \
              "Exceptions are our friends!"

        def_node_matcher :bangable_method?, PATTERN

        def on_send(node)
          bangable_method?(node) do
            if METHODS[@method_name].match(node)
              add_offense(
                node,
                location: :selector,
                message: format(MSG, @method_name)
              )
            end
          end
        end

        def bang_method?(arg_name)
          return false unless METHODS.key?(arg_name)
          @method_name = arg_name
          true
        end

        def autocorrect(node)
          lambda do |corrector|
            ctx = node.children[0] ? "#{node.children[0].source}." : ""
            corrector.replace(
              node.loc.expression,
              node.source.sub(
                "#{ctx}#{node.children[1]}",
                "#{ctx}#{@method_name}!"
              )
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module RuboCop
  module Cop
    module ActiveRecord
      class UpdateAttribute < RuboCop::Cop::Cop
        MSG = "Prefer the use of 'update_column' to force " \
              "the update of a column and skip the validation."

        def_node_matcher :update_attribute_method?, <<~PATTERN
          (
            send _ {:update_attribute! :update_attribute} {str sym lvar} _
          )
        PATTERN

        def on_send(node)
          update_attribute_method?(node) do
            add_offense(node, location: :selector)
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            ctx = node.children[0] ? "#{node.children[0].source}." : ""
            corrector.replace(
              node.loc.expression,
              node.source.sub(
                "#{ctx}#{node.children[1]}",
                "#{ctx}update_column"
              )
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module RuboCop
  module Cop
    module Documentation
      # This cop checks for missing swagger-yard documentation tag for
      # public methods. It should only be used on controllers.
      # To ensure this, the default path is set to app/controllers.
      # See https://github.com/rubocop-hq/rubocop/blob/master/lib/rubocop/cop/style/documentation_method.rb
      #
      # @example
      #
      #   # bad
      #
      #   class Foo
      #     def bar
      #       puts baz
      #     end
      #   end
      #
      #   # good
      #
      #   class Foo
      #
      #     # @path
      #     def bar
      #       puts baz
      #     end
      #
      #     private
      #     def ber
      #       puts bez
      #     end
      #   end
      #
      class CheckPathDocumented < Cop
        include DocumentationComment
        include DefNode

        MSG = 'Missing swagger-yard tag @path in method documentation comment.'

        def on_def(node)
          check(node)
        end
        alias on_defs on_def

        private

        def documentation_comment?(node)
          preceding_lines = preceding_lines(node)
          return false unless preceding_comment?(node, preceding_lines.last)

          preceding_lines.any? do |comment|
            path_tag_comment?(comment)
          end
        end

        def check(node)
          return if non_public?(node)

          return if documentation_comment?(node)

          add_offense(node, severity: :error)
        end

        def path_tag_comment?(comment)
          comment.text =~ /^#\s*@path.*/
        end
      end
    end
  end
end

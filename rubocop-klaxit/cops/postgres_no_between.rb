# frozen_string_literal: true

module RuboCop
  module Cop
    module PostgreSQL
      class NoBetween < Cop
        MSG = "Do NOT use BETWEEN in SQL"

        # Add offense when detect between in a string
        def on_str(node)
          return unless node.value.downcase.match?(/\s{1}\bbetween\b\s{1}/i)

          add_offense(node)
        end
      end
    end
  end
end

# frozen_string_literal: true

module RuboCop
  module Cop
    module PostgreSQL
      class NoBetween < Cop
        MSG = "Do NOT use BETWEEN in SQL"

        # Add offense when detect between in a string
        def on_str(node)
          add_offense(node) if node.value.match?(/\bbetween\b/i)
        end
      end
    end
  end
end

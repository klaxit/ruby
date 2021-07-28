# frozen_string_literal: true

module RuboCop
  module Cop
    module PostgreSQL
      # Using BETWEEN in PostgreSQL is a bad practice. We add a cop to detect
      # between keyword in string. It may give false positives.
      # See https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_BETWEEN_.28especially_with_timestamps.29
      class NoBetween < Cop
        MSG = "Do NOT use BETWEEN in PostgreSQL. Please refer to: "\
              "https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_BETWEEN_.28especially_with_timestamps.29"

        # Add offense when detect between in a string
        def on_str(node)
          return unless node.value.match?(/\bbetween\b/i)

          add_offense(node)
        end
      end
    end
  end
end

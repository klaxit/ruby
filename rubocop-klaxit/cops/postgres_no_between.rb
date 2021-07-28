# frozen_string_literal: true

module RuboCop
  module Cop
    module PostgreSQL
      # Using BETWEEN in PostgreSQL is a bad practice. We a cop to detect
      # between keyword in string.
      class NoBetween < Cop
        MSG = "Do NOT use BETWEEN in PostgreSQL. Please refer: "\
              "https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_BETWEEN_.28especially_with_timestamps.29"

        # Add offense when detect between in a string
        def on_str(node)
          return unless node.value.downcase.match?(/\s{1}\bbetween\b\s{1}/i)

          add_offense(node)
        end
      end
    end
  end
end

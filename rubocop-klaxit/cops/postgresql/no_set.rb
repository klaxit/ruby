# frozen_string_literal: true

module RuboCop
  module Cop
    module PostgreSQL
      # Cause of PGBouncer usage, checks that the SET operator is not
      # used in a SQL request in SESSION mode
      # SESSION is the default value when SESSION and LOCAL are omitted.
      # To avoid too many false positives we make sure that we are in a SQL
      # SET query by:
      # - Removing the SQL comment lines
      # - Making sure that the first operation is a SET and that the operation
      #   matches the pattern of the command
      class NoSet < Cop
        MSG = "Any changes to session state via SET should only be made with " \
              "SET LOCAL so that the changes are scoped only to the " \
              "currently executing transaction. Never use SET SESSION or " \
              "SET alone with PGBouncer, which defaults to SET SESSION " \
              "with transaction pooling. See: " \
              "https://devcenter.heroku.com/articles/best-practices-pgbouncer-configuration"

        # Add offense if bad SET use detected
        def on_dstr(node)
          result = ""

          # Aggregate string lines
          node.each_child_node do |item|
            next if item.type != :str
            # Skip commented lines
            next if item.value.match?(/^\s*--.*$/)
            result = result.dup.concat(item.value.gsub("\n", ""))
          end

          unless result.match?(
            /^SET(?! LOCAL)( SESSION)* [a-zA-Z_]+ *(TO|=)+ *.+/i
          )
            return
          end
          add_offense(node)
        end
      end
    end
  end
end

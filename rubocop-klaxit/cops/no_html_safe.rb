# frozen_string_literal: true

module RuboCop
  module Cop
    # Forbid usage of html_safe which can introduce XSS vulnerabilities
    class NoHtmlSafe < Cop
      MSG = "Prefer `sanitize` or `strip_tags` over usage of `html_safe`"
      RESTRICT_ON_SEND = %i(html_safe).freeze

      def on_send(node)
        add_offense(node)
      end
    end
  end
end

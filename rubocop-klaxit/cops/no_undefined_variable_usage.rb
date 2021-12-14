# frozen_string_literal: true

module RuboCop
  module Cop
    # This cop checks for local variable assignments with expressions
    # which self-references, and is not precedently defined.
    #
    # @example
    #   # bad
    #   foo = foo
    #
    #   # bad
    #   foo, bar = foo, bar
    #
    #   # bad
    #   def foo
    #   end
    #   foo = foo
    #
    #   # bad
    #   foo = 1 + foo + 2
    #
    #   # bad
    #   foo = foo.increment
    #
    #   # good
    #   foo = 10
    #   foo = foo
    class NoUndefinedVariableUsage < Cop
      MSG = "Variable used before being defined"

      def_node_matcher :has_param?, <<~PATTERN
        ({def defs block} <(args <(_ %1 ...)...>) ...>)
      PATTERN

      def_node_matcher :masgn_with_sym, <<~PATTERN
        (masgn (mlhs (lvasgn $_)*) ...)
      PATTERN

      def_node_search :lvar_with_sym, "(lvar %1)"

      # Check on local variable assignments, both single and multiple
      # @example `foo = 1`
      #   (lvasgn :foo
      #     (int 1))
      # @example `foo, bar = 1, 2`
      #   (masgn
      #     (mlhs
      #       (lvasgn :foo)
      #       (lvasgn :bar))
      #     (array
      #       (int 1)
      #       (int 2)))
      def on_lvasgn(node)
        sym = node.children[0]

        # Handle multiple assignments
        expr_node = node.parent&.mlhs_type? ? node.parent.parent : node
        return if lvar_with_sym(expr_node, sym).all? do |current_node|
          defined_before?(current_node, sym)
        end

        add_offense(node)
      end

      private

      # Recursive method which checks each parent context until definition is
      # found or until it is meaningless to check corresponding parent
      def defined_before?(current, sym)
        parent = current.parent

        # Local variable scope stays local, useless to look further
        # (scope does not leak outside method definition)
        return false if %i(def defs).include?(current.type)

        # Stop looking if in global scope (nil parent), scope does not leak
        # between files
        return false unless parent

        return true if has_param?(parent, sym)

        asgns = single_asgns(parent, sym) + multi_asgns(parent, sym)

        # Ensure the definitions come before the checked node
        return true if asgns.any? { _1.sibling_index < current.sibling_index }

        defined_before?(parent, sym)
      end

      def single_asgns(node, sym)
        node.each_child_node(:lvasgn).reject do |asgn_node|
          asgn_node.children[0] == sym && lvar_with_sym(asgn_node, sym).any?
        end
      end

      def multi_asgns(node, sym)
        node.each_child_node(:masgn).reject do |asgn_node|
          masgn_with_sym(asgn_node)&.include?(sym) &&
            lvar_with_sym(asgn_node.children[1], sym).any?
        end
      end
    end
  end
end

# frozen_string_literal: true

module RuboCop
  module Cop
    class NoUndefinedVariableUsage < Cop
      MSG = "Variable used before being defined"

      def_node_matcher :has_param?, <<~PATTERN
        ({def defs block} <(args <(_ %1 ...)...>) ...>)
      PATTERN

      def_node_matcher :masgn_with_sym, <<~PATTERN
        (masgn (mlhs (lvasgn $_)*) ...)
      PATTERN

      def_node_search :lvar_with_sym, "(lvar %1)"

      # :nodoc:
      def on_lvasgn(node)
        sym = node.children[0]

        return if lvar_with_sym(node, sym).all? { defined_before?(_1, sym) }

        add_offense(node)
      end

      # :nodoc:
      def on_masgn(node)
        syms = masgn_with_sym(node)

        return if syms.nil? || syms.all? do |sym|
          expr_node = node.children[1]
          lvar_with_sym(expr_node, sym).all? { defined_before?(_1, sym) }
        end

        add_offense(node)
      end

      private

      def defined_before?(current, sym)
        parent = current.parent

        return false if %i(def defs).include?(current.type) || parent.nil?
        return true if has_param?(parent, sym)

        asgns = single_asgns(parent, sym) + multi_asgns(parent, sym)

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

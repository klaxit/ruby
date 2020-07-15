# frozen_string_literal: true

module Klaxit
  class ConfigSorter
    # A group should not be ordered, it should stay as-is and can have a
    # top-comment.
    # Its contained elements should be ordered though.
    # Here's what a group looks like:
    #
    # ```
    # # foo        # <- comments
    # name: &foo   # <- definition
    #   <<: *bar   # <- attributes
    #   fizz: buzz # <- elements
    class Group
      attr_accessor :definition

      def initialize
        @elements = []
        @attributes = []
        @comments = []
      end

      # @param element [Element]
      def add_element(element)
        @elements << element
      end

      # @param line [String]
      def add_comment(line)
        @comments << line
      end

      # @param line [String]
      def add_attribute(line)
        @attributes << line
      end

      def to_s
        @comments.join("") +
          @definition +
          @attributes.join("") +
          @elements.sort.join("")
      end
    end

    # An element is contained in a group and should be ordered. It is defined
    # like this:
    #
    # ```
    #   # hello
    #   # world              # <- comments
    #   name: |
    #     foo
    #     bar                # <- content
    # ```
    #
    # And should be ordered by name.
    class Element
      include Comparable

      attr_accessor :name

      def initialize
        @comments = []
        @content = []
      end

      def to_s
        @comments.join("") +
          @content.join("")
      end

      # @param line [String]
      def add_comment(line)
        @comments << line
      end

      # @param line [String]
      def add_content(line)
        @content << line
      end

      def <=>(other)
        return nil unless other.is_a?(Element)

        name <=> other.name
      end
    end

    # The stateful pseudo-yaml parser. It will look for groups, and within
    # those for elements.
    class Parser
      require "strscan"

      class Error < StandardError
      end

      attr_reader :groups

      def initialize(str)
        @lineno = 1
        @buffer = StringScanner.new(str)
        @groups = []
        parse
      end

      private def parse
        until @buffer.eos?
          skip_blank_lines
          parse_group
        end
      end

      private def skip_blank_lines
        @lineno += 1 while @buffer.skip(/\s*\n/)
      end

      private def parse_group
        if @buffer.peek(1).match?(/[\w#]/)
          @groups << find_group
          parse_elements
        else
          raise Error, error_message("expecting a group")
        end
      end

      private def find_group
        group = Group.new
        find_group_header(group)
        find_group_attributes(group)
        group
      end

      # Top comment or definition.
      private def find_group_header(group)
        case check_line
        when /\A#/ # comment
          group.add_comment(next_line)
          find_group_header(group)
        when /\A\w/ # definition
          group.definition = next_line
        else
          raise Error, error_message
        end
      end

      private def find_group_attributes(group)
        case check_line
        when /\A  [^\w#]/ # attribute
          group.add_attribute(next_line)
          find_group_attributes(group)
        when /\A  [\w#]/ # nested element
          return
        when nil, /\A\s*\n/ # end of group
          return
        else
          raise Error, error_message
        end
      end

      private def parse_elements
        parse_element until @buffer.eos? || check_line.match?(/\A(?:\w|#|\s*\n)/)
      end

      private def parse_element
        unless check_line.match?(/\A  [\w#]/)
          raise Error, error_message("expecting a nested element")
        end

        @groups.last.add_element(find_element)
      end

      private def find_element
        element = Element.new
        find_element_header(element)
        find_element_content(element)
        element
      end

      def find_element_header(element)
        case check_line
        when /\A  #/ # comment
          element.add_comment(next_line)
          find_element_header(element)
        when /\A  (\w+)/ # definition
          element.name = $1
          element.add_content(next_line)
        else
          raise Error, error_message
        end
      end

      def find_element_content(element)
        case check_line
        when /\A {3,}/ # content
          element.add_content(next_line)
          find_element_content(element)
        end
      end

      private def next_line
        @lineno += 1
        @buffer.scan_until(/\n/)
      end

      private def check_line
        @buffer.check_until(/\n/)
      end

      private def error_message(extra = nil)
        extra = ", #{extra}" if extra
        <<~TEXT
         cannot parse line#{extra}
         #{@lineno}: #{check_line}
        TEXT
      end
    end

    attr_reader :file

    def initialize(file)
      @file = file
      @parser = Parser.new(IO.read(file))
    end

    # @return [String] the sorted file
    def sorted_file
      @sorted_file ||= @parser.groups.join("\n")
    end

    # Check if there is a change in the +file+, in other words: check if the
    # order was not correct.
    def changed?
      @changed ||= sorted_file != IO.read(file)
    end

    # Get a git diff between the current file and sorted file.
    # @return [String]
    def diff
      require "tempfile"
      new_file = Tempfile.new(["new_config.", ".yml"])
      new_file.write(sorted_file)
      result = `git diff --no-index -- #{file} #{new_file.path}`.gsub(
        no_slash_beginning(new_file.path),
        no_slash_beginning(file)
      )
    ensure
      new_file.close
      new_file.unlink
      result
    end

    # Since git diff is prepended by +a/+ or +b/+, we want to be sure paths
    # doesn't contain a leading slash.
    private def no_slash_beginning(string)
      string.reverse.chomp("/").reverse
    end
  end
end

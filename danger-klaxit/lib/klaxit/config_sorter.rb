# frozen_string_literal: true

module Klaxit
  class ConfigSorter
    attr_reader :file

    # Regexp that detects a group, and returns its name as first match.
    PARENT_RE = /\A(\w+):/.freeze
    # Regexp that detects any child key in a group, and returns its name as
    # first match.
    CHILD_RE = /\A  (\w+):/.freeze

    def initialize(file)
      @file = file
    end

    # @return [String] the sorted file
    def sorted_file
      @sorted_file ||= parse
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
      result = `git diff -- #{file} #{new_file.path}`.gsub(
        no_slash_beginning(new_file.path),
        no_slash_beginning(file)
      )
    ensure
      new_file.close
      new_file.unlink
      result
    end

    private

    def parse
      current_group = nil
      data_for_group = Hash.new { |h, k| h[k] = String.new }
      result_file = String.new
      first_group = true
      current_child = 0.chr
      IO.foreach(file) do |line|
        next if blank?(line)
        group = line if line.match?(PARENT_RE)
        # Handle top comment lines
        if current_group.nil? && group.nil?
          result_file += line
          next
        end

        # Handle change of group.
        if !group.nil? && group != current_group
          if current_group
            result_file += "\n" unless first_group
            first_group = false
            result_file += current_group
            data_for_group.sort_by(&:first).each do |(_key, line_block)|
              result_file += line_block
            end
          end

          # Reset for next round!
          current_group  = line
          data_for_group = Hash.new { |h, k| h[k] = String.new }
          # All data that must be first in a group
          current_child = 0.chr
          next
        end

        # Handle current line for current group.
        child = line[CHILD_RE, 1]
        current_child = child if child
        data_for_group[current_child] += line
      end
      # If there is still an unhandled group, handle it!
      unless data_for_group.empty?
        result_file += "\n" unless first_group
        first_group = false
        result_file += current_group
        data_for_group.sort_by(&:first).each do |(_key, line_block)|
          result_file += line_block
        end
      end
      result_file
    end

    def blank?(string)
      string.match?(/\A\s*\z/)
    end

    # Since git diff is prepended by +a/+ or +b/+, we want to be sure paths
    # doesn't contain a leading slash.
    def no_slash_beginning(string)
      string.reverse.chomp("/").reverse
    end
  end
end

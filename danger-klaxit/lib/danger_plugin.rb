# This plugin is very specifically designed to help CI within Klaxit projects.
# It is available here since it has to be accessible to private or public
# projects. And moreover, anyone is free to use a part of it if it matches your
# application needs.
#
# @example Run a full bunch of tests for a Klaxit Ruby project
#
#          klaxit.common
#
# @see klaxit/ruby
#
class Danger::DangerKlaxit < Danger::Plugin
  require "parser/current"

  def common
    fail_for_bad_commits
    warn_for_public_methods_without_specs
    warn_rubocop
  end

  def warn_rubocop
    rubocop.lint(files: git.modified_files + git.added_files,
                 inline_comment: true,
                 force_exclusion: true,
                 only_report_new_offenses: true)
  end

  # Inspects commit messages to stop someone from merging until the committer
  # squashes/edits his commits.
  def fail_for_bad_commits
    messages = git.commits.map(&:message)
    git_keywords = %w(p pick r reword e edit s squash f fixup x exec
                      b break d drop l label t reset m merge)
    git_keyword_rgx = /\A(#{git_keywords * "|"})!/i
    wip_rgx = /\bwip\b/i

    if messages.length != messages.uniq.length
      failure "There are two commits with the same message. Please squash them"
    end

    if messages.any? { |message| message.match? wip_rgx }
      failure "There is a WIP commit in this Pull Request, " \
              "please get rid of it before merging."
    end
    if messages.any? { |message| message.match? git_keyword_rgx }
      failure "There is a git keyword in your commits, please " \
              "\`git rebase -i\` before merging."
    end

    nil
  end

  def warn_for_public_methods_without_specs
    return failure("`spec` directory is missing") unless Dir.exist?("spec")

    spec_regex = /describe "([#.][^"]+)"/

    new_public_methods_by_ruby_file.each do |file, method_details|
      file = new_name_for_file(file)
      spec_file = "spec/" + file.sub(".rb", "_spec.rb").sub("app/", "")
      next warn("No spec found for file #{file}.") unless File.exist?(spec_file)

      specs = IO.foreach(spec_file)
                .map { |line| line[spec_regex, 1] }
                .to_set
                .tap { |set| set.delete(nil) }
      method_details.each do |details|
        next if specs.include?(details.name_with_prefix)

        warn("Missing spec for `#{details}`", file: file, line: details.line)
      end
    end
  end

  private

  def new_ruby_files_excluding_spec
    @new_ruby_files_excluding_spec ||= begin
      (git.modified_files + git.added_files)
        .grep(/\.rb$/)
        .grep_v(/^spec/)
    end
  end

  def new_name_for_file(file)
    @new_name_for_file ||= begin
      renamed = git.renamed_files.map { |h| [h[:before], h[:after]] }.to_h
      renamed.default_proc = ->(_, key) { key }
      renamed
    end
    @new_name_for_file[file]
  end

  def new_ruby_files_excluding_spec_and_rubocop
    @new_ruby_files_excluding_spec_and_rubocop ||=
      begin
        require "rubocop"
        rubocop_config = RuboCop::ConfigStore.new.for(".")
        new_ruby_files_excluding_spec
          .reject { |file| rubocop_config.file_to_exclude?(file) }
      end
  end

  # @return Hash<String, MethodDetails>
  def new_public_methods_by_ruby_file
    return @new_public_methods_by_ruby_file if @new_public_methods_by_ruby_file

    # DEBUG: show new ruby files
    # dbg_data = new_ruby_files_excluding_spec_and_rubocop * ?,
    # puts "new_ruby_files_excluding_spec_and_rubocop: #{dbg_data}"

    # https://regex101.com/r/xLymHd
    new_method_regex = /^\+\s+def \b(?:self\.)?([^(\s]+).*/
    new_methods_by_file =
      new_ruby_files_excluding_spec_and_rubocop.each_with_object({}) do |f, h|
        methods = git.diff_for_file(f)
                     .patch
                     .split("\n")
                     .map { |line| line[new_method_regex, 1]&.to_sym }
                     .to_set
                     .tap { |set| set.delete(nil) }
                     .tap { |set| set.delete(:initialize) }
        #            ^ Specs don't contain #initialize
        h[f] = methods unless methods.empty?
      end

    # DEBUG
    # puts "new_methods_by_file:",
    #      JSON.pretty_generate(new_methods_by_file.transform_values(&:to_a))
    @new_public_methods_by_ruby_file =
      new_methods_by_file.each_with_object({}) do |(file, names), hash|
        public_methods = public_methods_for_file(IO.read(new_name_for_file(file)))
                         .select { |details| names.member?(details.name) }
        hash[file] = public_methods unless public_methods.empty?
      end

    # DEBUG
    # puts "new_public_methods_by_ruby_file:",
    #      JSON.pretty_generate(@new_public_methods_by_ruby_file
    #                           .transform_values { |a| a.map(&:to_s) })
    @new_public_methods_by_ruby_file
  end

  MethodDetails = Struct.new(:class_path, :name, :is_instance_method, :line) do
    def name_with_prefix
      "#{is_instance_method ? "#" : "."}#{name}"
    end

    def to_s
      "#{class_path}#{name_with_prefix}"
    end
  end

  def public_methods_for_file(file_content)
    # DEBUG: show file content with lines.
    # file_content.split("\n").map.with_index { |e, i| puts "#{i+1}: #{e}" }
    ast = Parser::CurrentRuby.parse(file_content)
    is_begin = ->(node) { %i(begin kwbegin).include?(node.type) }
    is_class_or_module = ->(node) { %i(class module).include?(node.type) }

    if is_class_or_module[ast]
      return public_methods_for_class_or_module(ast).values
    end

    # This case happens when there is no class definition, for instance within
    # an ActiveAdmin view file. Since we do not need tests for these kind of
    # files, we return an empty array.
    return [] unless is_begin[ast]

    ast.children
       .select(&is_class_or_module)
       .flat_map { |node| public_methods_for_class_or_module(node).values }
  end

  # This will give a list, wether there is one single or multiple childs.
  def children_for_node(ast_node)
    if %i(begin kwbegin).include?(ast_node.children.last.type)
      ast_node.children.last.children
    else
      # Only one element
      [ast_node.children.last]
    end
  end

  def add_method(hash, ast_node, class_name:, method_name:, is_instance:)
    method = MethodDetails.new(class_name, method_name, is_instance,
                               ast_node.loc.first_line)
    hash[method.to_s] = method
  end

  def add_class_method_block(hash, ast_node, class_name)
    # We do not handle `self.` within sclass (`class << self`) nor nested
    # sclass since it would be bad practif anyway.
    # See https://stackoverflow.com/q/57570175/6320039.
    children_for_node(ast_node).each do |sub_node|
      break if sub_node.type == :send && sub_node.children[1] == :private
      next if sub_node.type != :def

      add_method(hash, sub_node, class_name: class_name,
                                 method_name: sub_node.children.first,
                                 is_instance: false)
    end
  end

  def public_methods_for_class_or_module(ast_class, class_parents = [])
    unless %i(class module).include?(ast_class.type)
      raise ArgumentError, "Not a module."
    end

    # Class is written this way:
    #
    #   (class (const nil :Foo) (const nil :Bar) (nil))
    #   "class Foo < Bar; end"
    #
    # Here we are interested in `:Foo`
    current_class = ast_class.children.first.children.last
    class_name = [*class_parents, current_class].join("::")

    # Empty module or class definition
    return {} if ast_class.children.last.nil?

    is_public = true
    children_for_node(ast_class).each_with_object({}) do |node, methods|
      case node.type
      when :class, :module
        methods.merge!(
          public_methods_for_class_or_module(
            node, [*class_parents, current_class]
          )
        )
      when :sclass then add_class_method_block(methods, node, class_name)
      when :send
        case node.children[1]
        when :private then is_public = false
        when :private_class_method
          methods.delete("#{class_name}.#{node.children.last.children.first}")
        end
      when :def
        is_public && add_method(methods, node, class_name: class_name,
                                               method_name: node.children.first,
                                               is_instance: true)
      when :defs
        # Format:
        #
        #   (defs (self) :foo (args) nil)
        #   "def self.foo; end"
        add_method(methods, node, class_name: class_name,
                                  method_name: node.children[1],
                                  is_instance: false)
      end
    end
  end
end

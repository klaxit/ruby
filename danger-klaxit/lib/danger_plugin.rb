# frozen_string_literal: true

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
    warn_for_public_methods_without_specs
    warn_for_bad_order_in_config
    warn_rubocop
    fail_for_not_updated_structure_sql
    run_brakeman_scanner if rails_like_project?
  end

  def warn_rubocop
    rubocop.lint(files: git.modified_files + git.added_files,
                 inline_comment: true,
                 force_exclusion: true,
                 only_report_new_offenses: true)
  end

  # Inspects commit messages to stop someone from merging until the committer
  # squashes/edits his commits.
  # Unused at Klaxit, we now use GitHub's squash & merge button.
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

  # Start a scan using `danger-brakeman_scanner`. Arguments are deduced from
  # the current path, and klaxit naming conventions (i.e `klaxit-<name>`).
  def run_brakeman_scanner(configs = { app_path: "." })
    configs[:github_repo] = github_repo.to_s if github_repo
    brakeman_scanner.run(configs)
  end

  def warn_for_public_methods_without_specs
    return failure("`spec` directory is missing") unless Dir.exist?("spec")

    spec_regex = /describe "([#.][^"]+)"/

    new_public_methods_by_ruby_file
      .each do |file, method_details|
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

  # Verify order in config.yml
  def warn_for_bad_order_in_config(config_file = "config/config.yml")
    return unless git.modified_files.include?(config_file)

    require_relative "klaxit/config_sorter"
    sorter = Klaxit::ConfigSorter.new(config_file)
    return unless sorter.changed?

    warn("#{config_file} is not correctly sorted! I've printed it [below](#config_file) for you.")
    markdown <<~MARKDOWN
      <a id="config_file"></a>Here's the updated configuration file:

      <details>

      ```yaml
      #{sorter.sorted_file}
      ```

      </details>

      And here's a diff that you can apply with `git apply <file>` if you're
      more of a git guy:

      <details>

      ```patch
      #{sorter.diff}
      ```

      </details>

      I know bots are not flawed, but since I've been designed by humans, you
      should still review before applying :wink:.
    MARKDOWN
  end

  # Check all migrations were saved in schema/structure file
  def fail_for_not_updated_structure_sql
    migration_files = git.added_files.grep(%r(db/migrate/.*rb))
    return nil if migration_files.empty?

    structure_file_exists = File.exist?("./db/structure.sql")
    schema_file_exists = File.exist?("./db/schema.rb")
    unless structure_file_exists || schema_file_exists
      return failure("You should commit your databases changes via" \
                     " `structure.sql` or `schema.rb` when you do a migration.")
    end

    added_migrations_timestamps = migration_files.map do |file|
      File.basename(file).partition("_").first.tr("_", "")
    end

    if schema_file_exists
      return fail_for_not_updated_schema(added_migrations_timestamps.max)
    end

    fail_for_missing_structure_timestamp(added_migrations_timestamps)
  end

  private

  def fail_for_missing_structure_timestamp(added_migrations_timestamps)
    structure_diff = git.diff_for_file("db/structure.sql").patch
    missing_timestamps = added_migrations_timestamps.reject do |ts|
      structure_diff.include?(ts)
    end
    return if missing_timestamps.empty?

    failure("Some migrations timestamps are missing: " \
            "#{missing_timestamps.join(", ")}")
  end

  def fail_for_not_updated_schema(max_added_migrations_timestamp)
    version_line = File.open("./db/schema.rb") do |f|
      f.find { _1[/^.*version: (.*?)\)/] }
    end
    version = version_line[/^.*version: (.*?)\)/, 1] if version_line
    return failure("Could not find version in schema file") unless version
    unless version.tr("_", "") >= max_added_migrations_timestamp
      failure("Version of schema.rb should be equal or higher than last " \
              "added migration timestamp")
    end
    return nil
  end

  def new_ruby_files_excluding_spec
    @new_ruby_files_excluding_spec ||= begin
      (git.modified_files + git.added_files)
        .grep(/\.rb$/)
        .grep_v(/^spec/)
    end
  end

  # This is sufficient in many cases since gem-like projects use `lib`, `ext`
  # but never `app` folder. And every app based project used by klaxit are
  # Sinatra or Rails project.
  def rails_like_project?
    Dir.exist?("app")
  end

  def github_repo
    github.html_link("")[%r(github.com/((?:[^/]+)/(?:[^/]+))), 1]
  rescue StandardError
    nil
  end

  def new_name_for_file(file)
    @new_name_for_file ||= begin
      renamed = git.renamed_files.map { |h| [h[:before], h[:after]] }.to_h
      renamed.default_proc = ->(_, key) { key }
      renamed
    end
    @new_name_for_file[file]
  end

  def new_ruby_files_excluding_spec_rubocop_and_migrations
    @new_ruby_files_excluding_spec_rubocop_and_migrations ||=
      begin
        require "rubocop"
        rubocop_config = RuboCop::ConfigStore.new.for(".")
        new_ruby_files_excluding_spec
          .reject { |file| rubocop_config.file_to_exclude?(file) }
          .reject { |file| file.start_with?("db/") }
          .reject { |file| file.start_with?("app/workers/migrations/") }
      end
  end

  # @return Hash<String, MethodDetails>
  def new_public_methods_by_ruby_file
    return @new_public_methods_by_ruby_file if @new_public_methods_by_ruby_file

    # DEBUG: show new ruby files
    # dbg_data = new_ruby_files_excluding_spec_rubocop_and_migrations * ?,
    # puts "new_ruby_files_excluding_spec_rubocop_and_migrations: #{dbg_data}"

    # https://regex101.com/r/xLymHd
    new_method_regex = /^\+\s+def \b(?:self\.)?([^(\s]+).*/
    new_methods_by_file =
      new_ruby_files_excluding_spec_rubocop_and_migrations.each_with_object({}) do |f, h|
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

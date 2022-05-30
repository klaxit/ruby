# frozen_string_literal: true

require_relative "spec_helper"

module Danger
  describe Danger::DangerKlaxit do
    it "should be a plugin" do
      expect(Danger::DangerKlaxit.new(nil)).to be_a Danger::Plugin
    end

    #
    # You should test your custom attributes and methods here
    #
    describe "with Dangerfile" do
      before do
        @dangerfile = testing_dangerfile
        @plugin = @dangerfile.klaxit
      end

      describe "#fail_for_bad_commits" do
        it "fails if there is a wip commit" do
          wip_message =
            ["WIP: todo", "this is wip", "wip", "warning wip warning"].sample
          allow(@plugin.git).to receive(:commits).and_return(
            [double(:commit, message: wip_message)]
          )

          @plugin.fail_for_bad_commits

          expect(@dangerfile.status_report[:errors]).to contain_exactly(
            "There is a WIP commit in this Pull Request, " \
            "please get rid of it before merging."
          )
        end

        it "fails if there are two commits with the same message" do
          allow(@plugin.git).to receive(:commits).and_return(
            [double(:commit, message: "Not original bro."),
             double(:commit, message: "Hey I'm different"),
             double(:commit, message: "Not original bro.")]
          )

          @plugin.fail_for_bad_commits

          expect(@dangerfile.status_report[:errors]).to contain_exactly(
            "There are two commits with the same message. Please squash them"
          )
        end

        it "fails if there is a commit with a git keyword as prefix" do
          keyword = %w(p pick r reword e edit s squash f fixup
                       x exec b break d drop l label t reset
                       m merge).sample + "!"
          allow(@plugin.git).to receive(:commits).and_return(
            [double(:commit, message: "#{keyword} some message")]
          )

          @plugin.fail_for_bad_commits

          expect(@dangerfile.status_report[:errors]).to contain_exactly(
            "There is a git keyword in your commits, please " \
            "\`git rebase -i\` before merging."
          )
        end
      end

      # TODO: To test this correctly, you have to mock git data and find a way
      #       to either mock filesystem or point to a fixture directory while
      #       calling IO::foreach / File.exist? / Dir.exist?
      # allow(@plugin.git).to receive(:modified_files).and_return(...)
      describe "#warn_for_public_methods_without_specs"

      describe "#public_methods_for_file" do
        let(:file_content) do
          <<~RUBY
            module Foo
              def some_method
              end
            end
          RUBY
        end
        subject do
          @plugin.send(:public_methods_for_file, file_content).map(&:to_s)
        end
        it { should contain_exactly "Foo#some_method" }
        context "when there is only one class method" do
          let(:file_content) do
            <<~RUBY
              class Foo
                class << self
                  def create
                  end
                end
              end
            RUBY
          end
          it { should contain_exactly "Foo.create" }
        end
        context "with nested modules and classes" do
          let(:file_content) do
            <<~RUBY
              module Foo
                class Bar
                  def conan
                  end
                end
                def some_method
                end
              end
            RUBY
          end
          it { should contain_exactly *%w(Foo::Bar#conan Foo#some_method) }
        end
        context "with private in the mix" do
          let(:file_content) do
            <<~RUBY
              require "stuff"

              class Foo
                def pub
                  content = priv
                  return content
                end

                private

                def priv
                  content = 42
                  return "I don't respect contract"
                end
              end
            RUBY
          end
          it { should contain_exactly "Foo#pub" }
        end
        context "with `self.` class methods" do
          let(:file_content) do
            <<~RUBY
              class Fizz
                def self.noop(value)
                  return value
                end
              end
            RUBY
          end
          it { should contain_exactly "Fizz.noop" }
        end
        context "when there is no class" do
          let(:file_content) do
            <<~RUBY
              ActiveAdmin.register do
                def i_m_a_method
                  "hello little world"
                end
              end
            RUBY
          end
          it { should be_empty }
        end
        context "when setting `self.` method as private" do
          let(:file_content) do
            <<~RUBY
              class Fizz
                def self.noop(value)
                  return value
                end
                private_class_method :noop
              end
            RUBY
          end
          it { should be_empty }
        end
        context "within a `class << self` block" do
          let(:file_content) do
            <<~RUBY
              class Buzz
                # trolling
                private

                class << self
                  def pub
                  end

                  private

                  def priv
                  end
                end
              end
            RUBY
          end
          it { should contain_exactly "Buzz.pub" }
        end
      end

      describe "#warn_for_bad_order_in_config" do
        let(:content) { nil }
        before do
          allow(@plugin.git).to receive(:modified_files) { modified_files }
          if content
            Dir.mkdir("config")
            IO.write("config/config.yml", content)
          end
        end
        after do
          FileUtils.rm_rf("config") if content
        end
        context "when config/config.yml has not been modified" do
          let(:modified_files) { [] }
          it "should not print anything" do
            @plugin.warn_for_bad_order_in_config
            expect(@plugin.status_report.values).to all be_empty
          end
        end
        context "when config/config.yml is in correct order" do
          let(:modified_files) { ["config/config.yml"] }
          let(:content) do
            <<~YAML
              # This is a top-comment
              foo: &foo
                # this is a
                a: 1
                # this is b
                b: 3
                c: |
                  coucou
                  tu
                  veux

              bar:
                <<: foo
                lol: cat
            YAML
          end
          it "should not print anything" do
            @plugin.warn_for_bad_order_in_config
            expect(@plugin.status_report.values).to all be_empty
          end
        end
        context "when file is badly ordered" do
          let(:modified_files) { ["config/config.yml"] }
          let(:content) do
            <<~YAML
              # This is a top-comment
              foo: &foo
                # this is b
                b: 3
                a: 1
                c: |
                  coucou
                  tu
                  veux
                d: la reponse d

              bar:
                <<: foo
                lol: cat
                c: |
                  voir
                  mes
                  bits
            YAML
          end
          it "should warn and help user to change the code" do
            @plugin.warn_for_bad_order_in_config
            expect(@plugin.status_report[:warnings].length).to be 1
            expect(@plugin.status_report[:markdowns].length).to be 1
            expect(@plugin.status_report[:markdowns].first.message.include?(
              <<~MARKDOWN
                ```yaml
                # This is a top-comment
                foo: &foo
                  a: 1
                  # this is b
                  b: 3
                  c: |
                    coucou
                    tu
                    veux
                  d: la reponse d

                bar:
                  <<: foo
                  c: |
                    voir
                    mes
                    bits
                  lol: cat

                ```
              MARKDOWN
            )).to be
          end
        end
      end

      describe "#fail_for_not_updated_structure_sql" do
        let(:structure_sql_diff) { "" }
        let(:schema_rb) { "" }
        let(:migration_timestamp) { Time.new }
        let(:migration_str) do
          migration_timestamp.strftime("%Y%m%d%H%M%S")
        end
        before do
          allow(@plugin.git).to receive(:added_files) { added_files }
          allow(@plugin.git).to receive(:modified_files) { modified_files }
          allow(@plugin.git).to receive(:diff_for_file) do |file|
            if file == "db/structure.sql"
              double(:diff, patch: structure_sql_diff)
            end
          end
        end
        context "when structure.sql and schema.rb are not updated" do
          let(:added_files) { ["db/migrate/#{migration_str}_a_migration.rb"] }
          let(:modified_files) { [] }

          it "should warn structure.sql or schema.rb is not updated" do
            @plugin.fail_for_not_updated_structure_sql
            expect(@dangerfile.status_report[:errors])
              .to include("You should commit your databases changes via" \
                " `structure.sql` or `schema.rb` when you do a migration.")
          end
        end

        context "when structure.sql is updated" do
          let(:added_files) { ["db/migrate/#{migration_str}_database_migration.rb"] }
          let(:modified_files) { ["db/structure.sql"] }
          let(:structure_sql_diff) do
            "(#{(migration_timestamp - rand(1..10_000)).strftime("%Y%m%d%H%M%S")}),"
          end

          it "should warn structure.sql is not up to date with migrations" do
            @plugin.fail_for_not_updated_structure_sql
            expect(@dangerfile.status_report[:errors])
              .to include(
                "Some migrations timestamps are missing: " \
                "#{migration_timestamp.strftime("%Y%m%d%H%M%S")}"
              )
          end
        end

        context "when structure.sql is updated and has migration timestamp" do
          let(:added_files) { ["db/migrate/#{migration_str}_migration.rb"] }
          let(:modified_files) { ["db/structure.sql"] }
          let(:structure_sql_diff) { "(#{migration_timestamp.strftime("%Y%m%d%H%M%S")})" }

          it "should not warn" do
            @plugin.fail_for_not_updated_structure_sql
            expect(@plugin.status_report.values).to all be_empty
          end
        end
        context "when structure.sql is updated and has migration timestamp and subfolder" do
          let(:added_files) do
            [
              "db/migrate/#{migration_str}_migration.rb",
              "db/migrate/#{migration_str}_migration/file_fixture.csv"
            ]
          end
          let(:modified_files) { ["db/structure.sql"] }
          let(:structure_sql_diff) do
            "(#{migration_timestamp.strftime("%Y%m%d%H%M%S")})"
          end

          it "should not warn" do
            @plugin.fail_for_not_updated_structure_sql
            expect(@plugin.status_report.values).to all be_empty
          end
        end
        context "when schema.rb exist" do
          let(:added_files) { ["db/migrate/#{migration_str}_database_migration.rb"] }
          let(:modified_files) { ["db/schema.rb"] }
          let(:schema_rb) do
            "+ version: " \
            "#{(migration_timestamp - rand(1..10_000)).strftime("%Y_%m_%d_%H%M%S")})"
          end

          before do
            allow(File)
              .to receive(:exist?)
              .with("./db/schema.rb")
              .and_return(true)
            allow(File)
            .to receive(:open)
            .with("./db/schema.rb")
            .and_return(schema_rb)
          end

          it "should warn schema.rb is not up to date with migrations" do
            @plugin.fail_for_not_updated_structure_sql
            expect(@dangerfile.status_report[:errors])
              .to include(
                "Version of schema.rb should be equal or higher than last " \
                "added migration timestamp"
              )
          end
          context "when schema version is newer" do
            let(:schema_rb) do
              "+ version: " \
              "#{(migration_timestamp + rand(1..10_000)).strftime("%Y_%m_%d_%H%M%S")})"
            end

            it "should not warn" do
              @plugin.fail_for_not_updated_structure_sql
              expect(@plugin.status_report.values).to all be_empty
            end
          end
          context "when schema version is equal to last added migrations" do
            let(:added_files) { ["db/migrate/#{migration_str.tr("_", "")}_migration.rb"] }
            let(:modified_files) { ["db/schema.rb"] }
            let(:schema_rb) { "+ version: #{migration_str})" }

            it "should not warn" do
              @plugin.fail_for_not_updated_structure_sql
              expect(@plugin.status_report.values).to all be_empty
            end
          end
        end
      end

      describe "#run_brakeman_scanner" do
        let(:brakeman_scanner) { double }
        let(:github_repo) { "klaxit/klaxit-example-app" }
        let(:gemfile_lock) { "" }

        before do
          allow(@plugin).to receive(:github_repo) { github_repo }
          allow(@dangerfile).to receive(:brakeman_scanner) { brakeman_scanner }
        end

        around do |example|
          Dir.chdir("#{__dir__}/support/fixtures/klaxit-example-app", &example)
        end

        it "runs brakeman with correct arguments" do
          expect(brakeman_scanner).to receive(:run).with({
            app_path: ".",
            github_repo: github_repo
          })
          @plugin.run_brakeman_scanner
        end
      end

      describe "#new_ruby_files_excluding_spec_rubocop_and_migrations" do
        before do
          allow(@plugin).to receive(:new_ruby_files_excluding_spec) do
            %W(
              db/migrate/mimimi.rb #{Dir.pwd}/script/rm_rf_slash.rb
              app/workers/migrations/migration.rb app/good.rb
            )
          end

          FileUtils.mv(".rubocop.yml", ".rubocop.yml.copy")
          IO.write(".rubocop.yml", <<~YAML)
            AllCops:
              Exclude:
                - db/**/*
                - script/**/*
          YAML
        end
        after do
          FileUtils.mv(".rubocop.yml.copy", ".rubocop.yml")
        end
        subject { @plugin.send(:new_ruby_files_excluding_spec_rubocop_and_migrations) }
        it { should contain_exactly "app/good.rb" }
      end

      describe "#github_repo" do
        it "gives info" do
          allow(@dangerfile.github).to receive(:html_link).with("") {
            "<a href='https://github.com/klaxit/klaxit-matcher/blob/5308f9c088370fd08aeb157f45db181d77d850f7/'></a>"
          }
          expect(@plugin.send(:github_repo)).to eq "klaxit/klaxit-matcher"
        end
      end

      describe "#rails_like_project?" do
        it "detect rails app" do
          Dir.chdir("#{__dir__}/support/fixtures/klaxit-example-app") do
            expect(@plugin.send(:rails_like_project?)).to be true
          end
          expect(@plugin.send(:rails_like_project?)).to be false
        end
      end
    end
  end
end

require File.expand_path("spec_helper", __dir__)

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
          expect(brakeman_scanner).to receive(:run).with(
            app_path: ".",
            github_repo: github_repo
          )
          @plugin.run_brakeman_scanner
        end
      end

      describe "#new_ruby_files_excluding_spec_and_rubocop" do
        before do
          allow(@plugin).to receive(:new_ruby_files_excluding_spec) do
            %W(db/migrate/mimimi.rb #{Dir.pwd}/script/rm_rf_slash.rb app/good.rb)
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
        subject { @plugin.send(:new_ruby_files_excluding_spec_and_rubocop) }
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

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
    end
  end
end

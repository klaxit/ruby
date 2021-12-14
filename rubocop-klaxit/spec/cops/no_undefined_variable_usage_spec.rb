# frozen_string_literal: true

RSpec.describe RuboCop::Cop::NoUndefinedVariableUsage, :config do
  it "registers an offense for simple self assignments" do
    expect_offense(<<~RUBY)
      foo = foo
      ^^^^^^^^^ Variable used before being defined
    RUBY
  end
  it "registers an offense for simple assignments with multiple nodes" do
    expect_offense(<<~RUBY)
      foo = 1 + foo - 3
      ^^^^^^^^^^^^^^^^^ Variable used before being defined
    RUBY
  end
  it "registers an offense for assignments using variable methods" do
    expect_offense(<<~RUBY)
      foo = foo.increment
      ^^^^^^^^^^^^^^^^^^^ Variable used before being defined
    RUBY
  end
  it "registers an offense for assignments which override method name" do
    expect_offense(<<~RUBY)
      def foo
        1
      end

      foo = foo
      ^^^^^^^^^ Variable used before being defined
    RUBY
  end
  it "registers an offense for assignments using variable in a block" do
    expect_offense(<<~RUBY)
      foo = begin
      ^^^^^^^^^^^ Variable used before being defined
        foo
      end
    RUBY
  end
  it "registers an offense for multiple self assignments" do
    expect_offense(<<~RUBY)
      foo, bar = foo, bar
      ^^^ Variable used before being defined
           ^^^ Variable used before being defined
    RUBY
  end
  it "registers an offense for assignments using definitions outside scope" do
    expect_offense(<<~RUBY)
      foo = 1
      def bar
        foo = foo
        ^^^^^^^^^ Variable used before being defined
      end
    RUBY
  end
  it "registers an offense for problematic assignments in parent contexts" do
    expect_offense(<<~RUBY)
      foo = foo
      ^^^^^^^^^ Variable used before being defined
      begin
        foo = foo
        ^^^^^^^^^ Variable used before being defined
        begin
          foo = foo
          ^^^^^^^^^ Variable used before being defined
        end
      end
    RUBY
  end
  it "accepts when colliding function names are referenced explicitly" do
    expect_no_offenses(<<~RUBY)
      def foo
        1
      end

      foo = foo()
    RUBY
    expect_no_offenses(<<~RUBY)
      def foo
        1
      end

      foo = self.foo
    RUBY
  end
  it "accepts when variable is a function parameter" do
    expect_no_offenses(<<~RUBY)
      def bar(foo)
        foo = foo
      end
    RUBY
  end
  it "accepts when variable is defined before use" do
    expect_no_offenses(<<~RUBY)
      a = 1
      a = a
    RUBY
  end
  it "accepts when there is one parent context with variable definition" do
    expect_no_offenses(<<~RUBY)
      foo = 1
      begin
        foo = foo
        begin
          foo = foo
        end
      end
    RUBY
  end
end

# frozen_string_literal: true

RSpec.describe RuboCop::Cop::NoHtmlSafe, :config do
  it "registers an offense when `html_safe` is called" do
    expect_offense(<<~RUBY)
      "toodaloo".html_safe
      ^^^^^^^^^^^^^^^^^^^^ Prefer `sanitize` or `strip_tags` over usage of `html_safe`
    RUBY
  end

  context "when string is interpolated" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        "\#{a}bb".html_safe
        ^^^^^^^^^^^^^^^^^^ Prefer `sanitize` or `strip_tags` over usage of `html_safe`
      RUBY
    end
  end

  context "when called on variable" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        a.html_safe
        ^^^^^^^^^^^ Prefer `sanitize` or `strip_tags` over usage of `html_safe`
      RUBY
    end
  end
end

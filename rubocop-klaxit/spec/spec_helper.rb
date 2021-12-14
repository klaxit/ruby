# frozen_string_literal: true

require "rubocop"
require "rubocop/cop/internal_affairs"
require "rubocop/rspec/support"

cop_path = File.join(__dir__, "..", "cops")
Dir["#{cop_path}/**/*.rb"].each { require_relative _1 }

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense

  config.order = :random

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
  end
end

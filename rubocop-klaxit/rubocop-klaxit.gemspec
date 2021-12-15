# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "klaxit/rubocop/gem_version"

Gem::Specification.new do |spec|
  spec.name          = "rubocop-klaxit"
  spec.version       = Klaxit::Rubocop::VERSION
  spec.authors       = ["Hugo BARTHELEMY"]
  spec.email         = ["dev@klaxit.com"]
  spec.summary       = "Ruby rules for Klaxit projects."
  spec.homepage      = "https://github.com/klaxit/ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r(^bin/)) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["rubocop/*"]

  spec.add_runtime_dependency "rubocop", [">= 0.44", "< 1"]

  spec.add_development_dependency "rspec"
end

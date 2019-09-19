lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "klaxit/gem_version"

Gem::Specification.new do |spec|
  spec.name          = "danger-klaxit"
  spec.version       = Klaxit::VERSION
  spec.authors       = ["Ulysse Buonomo"]
  spec.email         = ["dev@klaxit.com"]
  spec.summary       = "Danger for Klaxit projects."
  spec.homepage      = "https://github.com/klaxit/ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r(^bin/)) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "danger-plugin-api", "~> 1.0"

  spec.add_runtime_dependency "danger-rubocop", "~> 0.7"
  # Parser version is specified to 2.6.0 to facilitate a migration to Ruby 2.6.
  # Moreover, a lot of Gems need this version, hence we improve compatibility
  spec.add_runtime_dependency "parser", "~> 2.6.0"

  # General ruby development
  spec.add_development_dependency "bundler", "~> 2.0.2"
  spec.add_development_dependency "rake", "~> 10.0"

  # Testing support
  spec.add_development_dependency "rspec", "~> 3.4"

  # Linting code and docs
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "yard"

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency "guard", "~> 2.14"
  spec.add_development_dependency "guard-rspec", "~> 4.7"

  # This gives you the chance to run a REPL inside your tests
  # via:
  #
  #    require "pry"
  #    binding.pry
  #
  # This will stop test execution and let you inspect the results
  spec.add_development_dependency "pry"
end

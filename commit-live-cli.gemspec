# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'commit-live/version'

Gem::Specification.new do |spec|
  spec.name          = "commit-live-cli"
  spec.version       = CommitLive::Cli::VERSION
  spec.authors       = ["greyatom"]
  spec.email         = ["greyatomedutech@gmail.com"]

  spec.summary       = %q{Commit Live command line interface.}
  spec.homepage      = "https://github.com/greyatom-edu-tech/commit-live-cli"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.1.1"

  spec.files         = Dir["{bin,lib}/**/*", "LICENSE", "README.md"]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib", "bin"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  
  spec.add_dependency "thor", "~> 0.19", ">= 0.19.1"

  spec.add_runtime_dependency "netrc", "~> 0.11", ">= 0.11.0"
  spec.add_runtime_dependency "octokit", "~> 4.0"
  spec.add_runtime_dependency "json", "~> 2.0", ">= 2.0.2"
  spec.add_runtime_dependency "git", "~> 1.3", ">= 1.3.0"
  spec.add_runtime_dependency "faraday", "~> 0.9"
  spec.add_runtime_dependency "oj", "~> 2.9"
end

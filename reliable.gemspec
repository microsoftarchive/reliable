# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'reliable/version'

Gem::Specification.new do |spec|
  spec.name          = "reliable-queue"
  spec.version       = Reliable::VERSION
  spec.authors       = ["myobie"]
  spec.email         = ["me@nathanherald.com"]

  spec.summary       = %q{A reliable queue using redis}
  spec.description   = %q{A relialbe queue library for enqueuing and creating workers.}
  spec.homepage      = "https://github.com/wunderlist/reliable"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  spec.add_dependency "redic"
end

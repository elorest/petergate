# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'petergate/version'

Gem::Specification.new do |spec|
  spec.name          = "petergate"
  spec.version       = Petergate::VERSION
  spec.authors       = ["Isaac Sloan"]
  spec.email         = ["isaac@isaacsloan.com"]
  spec.summary       = %q{Authorization system allowing verbose easy read controller syntax.}
  spec.description   = %q{Authorization system.}
  spec.homepage      = "https://github.com/isaacsloan/petergate"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").delete_if{|p| p.include?("dummy/")}
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end

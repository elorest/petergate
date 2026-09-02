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
  spec.description   = %q{If you like the straight forward and effective nature of Strong Parameters and suspect that CanCan might be overkill for your project then you'll love Petergate's easy to use and read action and content based authorizations.}
  spec.homepage      = "https://github.com/elorest/petergate"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.metadata      = {
    "source_code_uri" => "https://github.com/elorest/petergate",
    "bug_tracker_uri" => "https://github.com/elorest/petergate/issues",
  }

  spec.files         = `git ls-files -z`.split("\x0").reject { |p| p.start_with?("test/", ".github/") }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.post_install_message = "NOTICE: As of version 1.5.0, the :admin role has been changed to :root_admin."

  spec.add_development_dependency "bundler", "> 1.7"
  spec.add_development_dependency "rake", ">= 12.3"

  # petergate reopens ActionController (actionpack) and calls String#pluralize
  # (activesupport), so both are real runtime dependencies -- not just activerecord.
  #
  # The floor is 7.1 because the roles column is declared with
  # `serialize :roles, coder: YAML`, and the coder: keyword arrived in 7.1.
  spec.add_dependency "activerecord",  ">= 7.1"
  spec.add_dependency "actionpack",    ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"
  # The railtie subclasses Rails::Railtie and the generators build on
  # Rails::Generators, both of which live in railties.
  spec.add_dependency "railties",      ">= 7.1"
end

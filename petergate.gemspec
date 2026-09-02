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
  spec.metadata      = {
    "source_code_uri" => "https://github.com/elorest/petergate",
    "bug_tracker_uri" => "https://github.com/elorest/petergate/issues",
  }

  spec.files         = `git ls-files -z`.split("\x0").reject { |p| p.start_with?("test/", "gemfiles/", ".github/") }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.post_install_message = "NOTICE: As of version 1.5.0, the :admin role has been changed to :root_admin."

  spec.add_development_dependency "bundler", "> 1.7"
  spec.add_development_dependency "rake", ">= 12.3"

  # petergate reopens ActionController (actionpack), calls String#pluralize
  # (activesupport), and subclasses Rails::Railtie (railties), so all three are
  # real runtime dependencies -- not just activerecord.
  #
  # The floors deliberately match the original activerecord constraint. Raising
  # them would refuse an upgrade to apps that work today: `serialize :roles,
  # coder: YAML` reads like a 7.1-only API, but on 7.0 and earlier `attribute`
  # swallows the unknown keyword and serialize falls through to
  # YAMLColumn.new(:roles, Object) -- the same column behaviour. CI verifies
  # Rails 7.1 through 8.1; older versions are permitted, not promised.
  spec.add_dependency "activerecord",  "> 4.0.0"
  spec.add_dependency "actionpack",    "> 4.0.0"
  spec.add_dependency "activesupport", "> 4.0.0"
  spec.add_dependency "railties",      "> 4.0.0"
end

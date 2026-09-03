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

  # assets/ holds the README's images, which the README loads from GitHub. They
  # are 350K of PNG that no runtime code touches, so they stay out of the gem --
  # they only shipped at all because moving them out of dummy/, which was
  # excluded here, put them on the default path.
  spec.files         = `git ls-files -z`.split("\x0").reject { |p| p.start_with?("test/", "gemfiles/", ".github/", "assets/") }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.post_install_message = "NOTICE: As of version 1.5.0, the :admin role has been changed to :root_admin."

  spec.add_development_dependency "bundler", "> 1.7"
  spec.add_development_dependency "rake", ">= 12.3"

  # petergate reopens ActionController (actionpack), calls String#pluralize
  # (activesupport), and subclasses Rails::Railtie (railties), so all three are
  # real runtime dependencies -- not just activerecord.
  #
  # 6.1 is the real floor, not a conservative one. `serialize :roles, coder:
  # YAML` needs a serialize that accepts keywords: 6.1 and 7.0 swallow the
  # unknown one and fall through to YAMLColumn.new(:roles, Object), and 7.1
  # added coder: for real. On 6.0 and earlier the signature is
  # serialize(attr_name, class_name_or_coder = Object) with no **options, so
  # Ruby binds the hash to the positional argument and the model raises
  # NoMethodError on load. CI covers 7.1 through 8.1.
  spec.add_dependency "activerecord",  ">= 6.1"
  spec.add_dependency "actionpack",    ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"
  spec.add_dependency "railties",      ">= 6.1"
end

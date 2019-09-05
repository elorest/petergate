require "petergate/version"
require "petergate/railtie"
require 'petergate/action_controller/base'
require 'petergate/active_record/base'

module Petergate
  def self.auth_class
    @@auth_class
  end

  def self.auth_class=(v)
    @@auth_class ||= v
  end
end

module Petergate
  class Railtie < Rails::Railtie
    config.app_generators do |g|
      g.scaffold_controller :scaffold_controller
      g.templates.unshift File::expand_path("../templates", File.dirname(__FILE__))
    end 
  end
end

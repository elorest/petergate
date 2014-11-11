# require 'petergate/view_helpers'
module Petergate
  class Railtie < Rails::Railtie
    initializer "petergate.libs" do
      ActiveSupport.on_load(:action_controller) do
        ActionController::Base.send(:include, Petergate::ControllerMethods)
      end
    end
  end
end

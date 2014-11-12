require 'petergate/view_helpers'
module Petergate
  class Railtie < Rails::Railtie
    initializer "petergate.libs" do
      ActiveSupport.on_load(:action_controller) do
        ActionController::Base.send(:include, Petergate::ControllerMethods)
      end

      ActiveSupport.on_load(:active_record) do
        User.send(:include, Petergate::ModelMethods)
      end
    end
  end
end

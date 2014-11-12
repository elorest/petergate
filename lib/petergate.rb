require "petergate/version"
# require 'petergate/railtie' if defined?(Rails)

module PeterGate
  module ControllerMethods
    module ClassMethods
      def access(rules = {}, &block)
        if block
          b_rules = block.call
          rules = rules.merge(b_rules) if b_rules.is_a?(Hash)
        end
        def check_access
          perms(rules)
        end
      end
    end

    AllRest = [:show, :index, :new, :edit, :update, :create, :destroy]

    def self.included(base)
      base.extend(ClassMethods)
      base.before_filter do 
        unless logged_in?(:admin)
          message= check_access
          if message.is_a?(String) || message == false
            if user_signed_in?
              redirect_to (request.referrer || after_sign_in_path_for(current_user)), :notice => message || "Permission Denied"
            else
              authenticate_user!
            end
          end
        end
      end
    end

    def check_access
      permissions
    end

    def permissions(rules = {all: [:index, :show], customer: [], wiring: []})
      # Allows Array's of keys for he same hash.
      rules = rules.inject({}){|h, (k, v)| k.class == Array ? h.merge(Hash[k.map{|kk| [kk, v]}]) : h.merge(k => v) }
      case params[:action].to_sym
      when *(rules[:all]) # checks where the action can be seen by :all
        true
      when *(rules[:user]) # checks if the action can be seen for all users
        user_signed_in?
      when *(rules[(user_signed_in? ? current_user.role.to_sym : :all)]) # checks if action can be seen by the  current_users role. If the user isn't logged in check if it can be seen by :all
        true
      else
        false
      end
    end

    alias_method :perms, :permissions

    def logged_in?(*roles)
      current_user && (roles & current_user.roles).any?
    end
  end
end

class ActionController::Base
  include PeterGate::ControllerMethods
end

require "petergate/version"
require "petergate/railtie"

module Petergate
  module ControllerMethods
    module ClassMethods
      def access(rules = {}, &block)
        if block
          b_rules = block.call
          rules = rules.merge(b_rules) if b_rules.is_a?(Hash)
        end

        instance_eval do
          @_controller_rules = rules

          def controller_rules
            @_controller_rules
          end
        end

        class_eval do
          def check_access
            permissions(self.class.controller_rules)
          end
        end
      end
    end

    AllRest = [:show, :index, :new, :edit, :update, :create, :destroy]

    def self.included(base)
      base.extend(ClassMethods)
      base.helper_method :logged_in?
      base.before_filter do 
        unless logged_in?(:admin)
          message= defined?(check_access) ? check_access : true
          if message.is_a?(String) || message == false
            if user_signed_in?
              respond_to do |format|
                format.any(:js, :json, :xml) { render nothing: true, status: :forbidden }
                format.html do
                  redirect_to (request.referrer || after_sign_in_path_for(current_user)), :notice => message || "Permission Denied"
                end
              end
            else
              authenticate_user!
            end
          end
        end
      end
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

    def logged_in?(*roles)
      current_user && (roles & current_user.roles).any?
    end

  end

  module UserMethods
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def petergate(options = {roles: [:admin]})
        serialize :roles
        after_initialize do
          self[:roles] ||= []
        end

        instance_eval do
          const_set('ROLES', options[:roles])
        end


        class_eval do
          def available_roles
            self.class::ROLES
          end

          def roles=(v)
            self[:roles] = v.map(&:to_sym).to_a.select{|r| r.size > 0 && available_roles.include?(r)}
          end

          def roles
            self[:roles] + [:user]
          end

          def role
            roles.first
          end
        end
      end
    end
  end
end

class ActionController::Base
  include Petergate::ControllerMethods
end

class ActiveRecord::Base
  include Petergate::UserMethods
end

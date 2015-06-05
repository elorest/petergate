require "petergate/version"
require "petergate/railtie"

module Petergate
  module ControllerMethods
    module ClassMethods
      def const_missing(const_name)
        if [:AllRest, :ALLREST].include?(const_name)
          warn "`AllRest` and `ALLREST` has been deprecated. Use :all instead."
          return ALLRESTDEP
        else
          return super 
        end
      end

      def all_actions
        ->{self.action_methods.to_a.map(&:to_sym) - [:check_access, :title]}.call
      end

      def except_actions(arr = [])
        all_actions - arr
      end

      def access(*params, &block)
        rules = params.last || {user: :all}
        unless (class_name = params.first).is_a? Symbol
          class_name = :user
        end

        if block
          b_rules = block.call
          rules = rules.merge(b_rules) if b_rules.is_a?(Hash)
        end

        instance_eval do
          @_controller_rules = rules
          @_user_object = class_name

          def user_object
            @_user_object 
          end

          def controller_rules
            @_controller_rules
          end
        end

        class_eval do
          def check_access
            permissions(self.class.controller_rules)
          end

          def user_method(um)
            self.send(um.gsub!("user", self.class.user_object.to_s))
          end
        end
      end
    end

    ALLRESTDEP = [:show, :index, :new, :edit, :update, :create, :destroy]

    def self.included(base)
      base.extend(ClassMethods)
      base.helper_method :logged_in?, :forbidden!
      base.before_filter do 
        unless logged_in?(:admin)
          message= defined?(check_access) ? check_access : true
          if message.is_a?(String) || message == false
            if user_method("user_signed_in?")
              forbidden! message
            else
              user_method("authenticate_user!")
            end
          end
        end
      end
    end

    def parse_permission_rules(rules)
      rules = rules.inject({}) do |h, (k, v)| 
        special_values = case v.class.to_s
                         when "Symbol"
                           v == :all ? self.class.all_actions : raise("No action for: #{v}")
                         when "Hash"
                           v[:except].present? ? self.class.except_actions(v[:except]) : raise("Invalid values for except: #{v.values}")
                           when "Array"
                             v
                           else
                             raise("No action for: #{v}")
                           end

        h.merge({k => special_values})
      end
      # Allows Array's of keys for he same hash.
      rules.inject({}){|h, (k, v)| k.class == Array ? h.merge(Hash[k.map{|kk| [kk, v]}]) : h.merge(k => v) }
    end

    def permissions(rules = {all: [:index, :show], customer: [], wiring: []})
      rules = parse_permission_rules(rules)
      case params[:action].to_sym
      when *(rules[:all]) # checks where the action can be seen by :all
        true
      when *(rules[:user]) # checks if the action can be seen for all users
        user_method("user_signed_in?")
      when *(rules[(user_method("user_signed_in?") ? user_method("current_user").role.to_sym : :all)]) # checks if action can be seen by the  current_users role. If the user isn't logged in check if it can be seen by :all
        true
      else
        false
      end
    end

    def user_method(um)
      self.send(um)
    end

    def logged_in?(*roles)
      user_method("current_user") && (roles & user_method("current_user").roles).any?
    end

    def forbidden!(msg = nil)
      respond_to do |format|
        format.any(:js, :json, :xml) { render nothing: true, status: :forbidden }
        format.html do
          destination = user_method("current_user").present? ? request.referrer || after_sign_in_path_for(user_method("current_user")) : root_path
          redirect_to destination, notice: msg || 'Permission Denied'
        end
      end
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
            self[:roles] = Array(v).map(&:to_sym).to_a.select{|r| r.size > 0 && available_roles.include?(r)}
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

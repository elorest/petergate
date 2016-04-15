module Petergate
  module ActionController
    module Base
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

        def access(rules = {}, &block)
          if block
            b_rules = block.call
            rules = rules.merge(b_rules) if b_rules.is_a?(Hash)
          end

          instance_eval do
            @_controller_rules = rules
            @_controller_message = rules.delete(:message)

            def controller_rules
              @_controller_rules
            end

            def controller_message
              @_controller_message || "Permission Denied"
            end

            def inherited(subclass)
              subclass.instance_variable_set("@_controller_rules", instance_variable_get("@_controller_rules"))
              subclass.instance_variable_set("@_controller_message", instance_variable_get("@_controller_message"))
            end
          end

          class_eval do
            def check_access
              permissions(self.class.controller_rules)
            end
          end
        end
      end

      ALLRESTDEP = [:show, :index, :new, :edit, :update, :create, :destroy]

      def self.included(base)
        base.extend(ClassMethods)
        base.helper_method :logged_in?, :forbidden!
        base.before_filter do 
          unless logged_in?(:root_admin)
            message= defined?(check_access) ? check_access : true
            if message == false || message.is_a?(String)
              if current_user || @user
                forbidden! message
              else
                unauthorized!
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
        rules = rules.inject({}){|h, (k, v)| k.class == Array ? h.merge(Hash[k.map{|kk| [kk, v]}]) : h.merge(k => v) }
      end

      def permissions(rules = {all: [:index, :show], customer: [], wiring: []})
        rules = parse_permission_rules(rules)
        allowances = [rules[:all]]
        current_user.roles.each do |role|
          allowances << rules[role]
        end if logged_in?(:user)
        allowances.flatten.compact.include?(action_name.to_sym)
      end

      def logged_in?(*roles)
        current_user && (roles & current_user.roles).any?
      end

      def custom_message
        defined?(self.class.controller_message) ? self.class.controller_message : 'Permission Denied'
      end

      def unauthorized!
        respond_to do |format|
          format.any(:js, :json, :xml) { render nothing: true, status: :unauthorized }
          format.html do
            authenticate_user! 
          end
        end
      end

      def forbidden!(msg = nil)
        respond_to do |format|
          format.any(:js, :json, :xml) { render nothing: true, status: :forbidden }
          format.html do
            destination = current_user.present? ? request.referrer || after_sign_in_path_for(current_user) : root_path
            redirect_to destination, notice: (msg || custom_message)
          end
        end
      end
    end
  end
end

class ActionController::Base
  include Petergate::ActionController::Base
end

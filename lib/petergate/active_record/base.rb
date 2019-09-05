module Petergate
  module ActiveRecord
    module Base
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def petergate(roles: [:admin], multiple: true)
          Petergate.auth_class = self.to_s.downcase

          if multiple
            serialize :roles
            after_initialize do
              self[:roles] ||= [:user]
            end
          else
            after_initialize do
              self[:roles] ||= :user 
            end
          end

          instance_eval do
            const_set('ROLES', (roles + [:user]).uniq.map(&:to_sym)) unless defined?(User::ROLES)

            if multiple
              roles.each do |role|
                define_singleton_method("role_#{role.to_s.pluralize}".downcase.to_sym){self.where("roles LIKE '%- :#{role}\n%'")}
              end
            else
              roles.each do |role|
                define_singleton_method("role_#{role.to_s.pluralize}".downcase.to_sym){self.where(roles: role)}
              end
            end
          end

          class_eval do
            def available_roles
              self.class::ROLES
            end

            if multiple
              def roles=(v)
                self[:roles] = (Array(v).map(&:to_sym).select{|r| r.size > 0 && available_roles.include?(r)} + [:user]).uniq
              end
            else
              def roles=(v)
                r = case v.class.to_s
                    when "String", "Symbol"
                      v
                    when "Array"
                      v.first
                    end.to_sym
                self[:roles] = available_roles.include?(r) ? r : :user 
              end
            end

            def roles
              case self[:roles].class.to_s
              when "String", "Symbol"
                [self[:roles].to_sym, :user].uniq
              when "Array"
                super
              else
                [:user]
              end
            end

            alias_method :role=, :roles=

            def role
              roles.first
            end

            def has_roles?(*roles)
              (roles & self.roles).any?
            end

            alias_method :has_role?, :has_roles?
          end
        end
      end
    end
  end
end

class ActiveRecord::Base
  include Petergate::ActiveRecord::Base
end

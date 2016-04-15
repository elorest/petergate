module Petergate
  module ActiveRecord
    module Base
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def petergate(roles: [:admin], multiple: true)
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
            const_set('ROLES', (roles + [:user]).uniq) unless defined?(User::ROLES)
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
                self[:roles] = case v.class.to_s
                               when "String", "Symbol"
                                 v
                               when "Array"
                                 v.first
                               end
              end
            end

            def roles
              case self[:roles].class.to_s
              when "String", "Symbol"
                [self[:roles].to_sym, :user]
              when "Array"
                super
              else
                [:user]
              end
            end

            def role
              roles.first
            end
          end
        end
      end
    end
  end
end

class ActiveRecord::Base
  include Petergate::ActiveRecord::Base
end

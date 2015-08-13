module Petergate
  module ActiveRecord
    module Base
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
end

class ActiveRecord::Base
  include Petergate::ActiveRecord::Base
end

# Included into ActiveRecord::Base, through the load hook at the bottom of
# this file.
module Petergate
  module ActiveRecord
    module Base
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def petergate(roles: [:admin], multiple: true)
          if multiple
            serialize :roles, coder: YAML
            after_initialize do
              self[:roles] ||= [:user]
            end
          else
            after_initialize do
              self[:roles] ||= :user 
            end
          end

          instance_eval do
            # Own constant only, so each model that calls petergate gets its own
            # roles rather than deferring to whichever model loaded first.
            # Configuring the same model twice keeps the first set.
            const_set('ROLES', (roles + [:user]).uniq.map(&:to_sym)) unless const_defined?(:ROLES, false)

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
                self[:roles] = (Array(v).compact.map(&:to_sym).select{|r| r.size > 0 && available_roles.include?(r)} + [:user]).uniq
              end
            else
              def roles=(v)
                r = case v.class.to_s
                    when "String", "Symbol"
                      v
                    when "Array"
                      v.first
                    end&.to_sym
                self[:roles] = available_roles.include?(r) ? r : :user
              end
            end

            # Only roles this record's own class defines.
            #
            # `roles=` filters against available_roles, but the column outlives
            # the class that wrote it. An STI `type` change is the sharp case:
            # the row keeps the roles of the kind it used to be, and those roles
            # would otherwise still satisfy `access`, granting a Customer what
            # was written for an Employee. Removing a role from a `petergate`
            # declaration leaves the same residue behind.
            #
            # A subclass with its own petergate call is checked against its own
            # ROLES; one without inherits its parent's, which is the constant
            # lookup doing the right thing.
            def roles
              # Deliberately no to_sym on the Array branch. `roles=` has always
              # written symbols there, so an array of strings can only have come
              # from a raw write -- update_column, an import, a fixture -- and
              # normalizing it would start granting a role that previously
              # matched nothing. Rejecting it keeps this release unable to widen
              # access, and the warning says the data is wrong.
              #
              # The single-role branch does symbolize, because it always has:
              # `role = "editor"` from a form is the documented way to set it.
              stored = case self[:roles].class.to_s
                       when "String", "Symbol"
                         [self[:roles].to_sym]
                       when "Array"
                         Array(self[:roles]).compact
                       else
                         []
                       end

              permitted, rejected = stored.partition { |role| available_roles.include?(role) }
              Petergate.warn_about_unavailable_roles(self.class, rejected) if rejected.any?

              (permitted + [:user]).uniq
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

# Hook in lazily so ActiveRecord::Base is not forced to load during boot,
# before the app has finished applying its own `config.active_record` settings.
ActiveSupport.on_load(:active_record) do
  include Petergate::ActiveRecord::Base
end

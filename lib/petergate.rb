require "petergate/version"
require "petergate/railtie"
require "petergate/rule"
require 'petergate/action_controller/base'
require 'petergate/active_record/base'

module Petergate
  # The Devise scope a declared petergate scope resolves to.
  #
  # A Symbol is taken at face value: it names the Devise mapping (or, without
  # Devise, whatever `current_<name>` the application provides). A Class is
  # looked up in Devise's mappings -- an exact match first, so a model with its
  # own `devise_for` wins over an ancestor's, which is what `find_scope!` alone
  # gets wrong for STI. A class with no mapping of its own resolves to its
  # nearest mapped ancestor: under STI that is the parent's scope, which is
  # correct, because there is only one login.
  #
  # Devise.mappings is read lazily, never at boot: on Rails 8 it calls
  # reload_routes_unless_loaded.
  def self.devise_scope_for(declared)
    return declared unless declared.is_a?(Class)
    return derived_scope_for(declared) unless defined?(::Devise) && ::Devise.respond_to?(:mappings)

    mappings = ::Devise.mappings
    exact = mappings.each_value.find { |mapping| mapping.to == declared }
    return exact.name if exact

    ::Devise::Mapping.find_scope!(declared)
  rescue StandardError
    # Devise has no mapping covering this class -- either it is not installed,
    # or authentication is hand-rolled, which the README supports. Fall back to
    # the class's own name.
    derived_scope_for(declared)
  end

  # Roles already warned about, and the lock guarding it. Created at load time:
  # a lazy `||=` would itself race on the authorization path.
  @warned_roles      = {}
  @warned_roles_lock = Mutex.new

  # Reports a stored role that the record's own class does not define.
  #
  # Once per class and role: this is read on every authorization check, and a
  # warning per request would be noise rather than a signal. Kernel#warn rather
  # than ActiveSupport::Deprecation -- nothing is deprecated, and the data is
  # wrong now.
  def self.warn_about_unavailable_roles(klass, rejected)
    rejected.each do |role|
      key = [klass.name, role]

      # Reached from the authorization path of every request, so without this
      # concurrent threads could mutate the hash while another iterates it.
      first_time = @warned_roles_lock.synchronize do
        next false if @warned_roles.key?(key)

        @warned_roles[key] = true
      end
      next unless first_time

      warn "petergate: #{klass.name} is ignoring the stored role #{role.inspect}. " +
           if role.is_a?(String) && klass::ROLES.include?(role.to_sym)
             "#{klass.name} declares #{role.to_sym.inspect}, but the column holds it as a " \
             "string. petergate stores roles as symbols, so this row was written by something " \
             "other than `roles=` -- raw SQL, update_column, or an import."
           else
             "#{klass.name} does not declare it; #{klass.name}::ROLES is #{klass::ROLES.inspect}. " \
             "A record whose type changed, or a role removed from a petergate declaration, " \
             "leaves roles behind in the column."
           end
    end
  end

  # The scope name a class implies when Devise cannot answer.
  #
  # Derived from the STI *base* class, so subclasses sharing one table share one
  # scope -- `Employee < User` asks `current_user`, which is the whole point of
  # STI -- while an independent model gets a scope of its own.
  def self.derived_scope_for(klass)
    base = klass.respond_to?(:base_class) ? klass.base_class : klass
    base.model_name.singular_route_key.to_sym
  rescue StandardError
    :user
  end

  # The scope name this class would have entirely on its own, ignoring any
  # hierarchy. Used only to tell "resolved to something else's login" from
  # "resolved to its own", which the missing-scope message reports differently.
  def self.own_scope_name_for(klass)
    klass.model_name.singular_route_key.to_sym
  rescue StandardError
    nil
  end
end

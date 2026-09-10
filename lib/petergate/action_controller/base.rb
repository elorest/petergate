# Included into ActionController::Base *and* ActionController::API: Rails runs
# the :action_controller load hook for both. See the hook at the bottom of this
# file for why that hook rather than the Base/API-specific pair.
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

        # Every action on this controller, and nothing else.
        #
        # Rails' own `action_methods` is not that list. `internal_methods` stops
        # at the first abstract controller and then adds back
        # `public_instance_methods(false)` for each concrete class below it, so
        # a public helper defined on a concrete superclass -- `current_user`
        # overridden in ApplicationController, say, or anything `devise_group`
        # generates -- comes back as an action and gets swept into `:all` and
        # `except:` rules.
        #
        # Rather than blocklisting names, ask whether a method could be an
        # action at all: Rails dispatches actions by name with no arguments, and
        # a helper_method is by definition not one.
        #
        # Memoized against the identity of Rails' own action_methods Set. Rails
        # replaces that Set whenever a method is added to the controller, so
        # this inherits Rails' invalidation instead of hooking method_added,
        # which would put a method on every controller in the application for an
        # app to override without noticing.
        def all_actions
          methods = action_methods
          return @_petergate_all_actions if @_petergate_action_methods.equal?(methods)

          # Frozen: it is handed straight to callers, and a caller mutating it
          # would corrupt every later :all and except: expansion.
          actions = petergate_action_names(methods).freeze

          # The value before the guard. Assigning the guard first would let
          # another thread see it set, take the early return, and get the nil
          # value -- which reaches parse_permission_rules on the authorization
          # path, where `:all` silently expands to nothing and `except:` raises
          # NoMethodError on nil.
          @_petergate_all_actions    = actions
          @_petergate_action_methods = methods
          actions
        end

        def except_actions(arr = [])
          all_actions - arr
        end

        # The auth model this controller's rules are about, inherited by
        # subclasses. Called with no argument it reads the current value.
        #
        # Takes a Class -- `petergate_scope Employee` -- or a Symbol naming a
        # Devise mapping. A Class works for both an STI subclass sharing one
        # login and a separately mapped model; see Petergate.devise_scope_for.
        def petergate_scope(scope = nil)
          return petergate_default_scope if scope.nil?

          petergate_validate_scope!(scope)
          self.petergate_default_scope = scope.is_a?(Class) ? scope : scope.to_sym
        end

        # access [scope], [denial message], role => actions, ...
        #
        # The scope and the message are positional, not keys in the rules hash.
        # Neither names a role, and burying them among the roles made them look
        # like ones -- and made those two names unusable as roles.
        #
        #   access all: [:index], admin: :all      # current_user, as always
        #   access Employee, support: :all         # an STI subclass
        #   access Vendor,   supplier: :all        # a separately mapped model
        #   access :member,  admin: :all           # a Devise mapping by name
        #   access "Staff only", admin: :all       # a denial message
        #   access Employee, "Staff only", support: :all
        #
        # A scope is a Class or a Symbol and a message is a String, so they are
        # told apart by type and may be given in either order.
        def access(*args, **rules, &block)
          # A braced hash arrives positionally: access({[:all, :user] => [...]}).
          rules = args.pop.merge(rules) if args.last.is_a?(::Hash)

          scope   = args.find { |arg| arg.is_a?(::Class) || arg.is_a?(::Symbol) }

          petergate_validate_scope!(scope)
          message = args.find { |arg| arg.is_a?(::String) }

          # delete_at rather than Array#-, which removes every equal element and
          # so let `access :staff, :staff, ...` through as though the repeat had
          # been asked for.
          unexpected = args.dup
          [scope, message].compact.each { |arg| unexpected.delete_at(unexpected.index(arg)) }
          # empty? rather than any?: `any?` without a block skips falsy
          # elements, so `access false, user: [:index]` was accepted silently.
          unless unexpected.empty?
            raise ArgumentError, "access takes a scope (a class or symbol) and a denial " \
                                 "message (a string) before its rules, got #{unexpected.inspect}"
          end

          if block
            b_rules = block.call
            rules = rules.merge(b_rules) if b_rules.is_a?(Hash)
          end

          # dup before deleting: the hash belongs to the caller, and the old
          # code mutated it as a side effect of reading :message out.
          rules = rules.dup

          # `message:` in the hash is deprecated: it names nothing in the role
          # vocabulary, and having it there is what made :message unusable as a
          # role name. A positional string wins when both are given.
          #
          # Kernel#warn rather than ActiveSupport::Deprecation, matching the
          # AllRest deprecation above -- and because a gem-owned deprecator
          # registered with the app would raise under the suite's
          # `config.active_support.deprecation = :raise`.
          if rules.key?(:message)
            source = caller_locations(1, 1)&.first
            warn "petergate: passing `message:` to `access` is deprecated. Give the message " \
                 "as a string before the rules instead -- `access \"...\", user: [:index]`." \
                 "#{" Called from #{source.path}:#{source.lineno}." if source}"
          end

          message ||= rules.delete(:message)
          rules.delete(:message)

          # A rule that named no scope follows the reading controller's
          # petergate_scope, so it is filed under a sentinel and resolved when
          # read. Rewriting keys at declaration time cannot see subclasses yet.
          #
          # No normalization: the find above admits only a Class or a Symbol,
          # and a String is refused outright, so there is nothing left to coerce.
          defaulted = scope.nil?
          key       = defaulted ? Petergate::DEFAULT_SCOPE : scope

          # A subclass declaring `access` replaces everything it inherited, the
          # way it always has. Only calls within one class body accumulate.
          #
          # Merging across the hierarchy instead would silently widen access on
          # upgrade: a subclass that narrows its parent -- the documented reason
          # to declare `access` again -- would keep the parent's wider rule live
          # beside its own, and OR them.
          petergate_claim_rules!

          # Keyed by the scope *as declared*, not by the Devise scope it
          # resolves to. Under STI `Employee` and `Manager` both resolve to the
          # same Devise scope, and keying on that would make the second
          # declaration silently replace the first instead of widening access.
          #
          # Re-declaring the same scope replaces it, which is what subclasses
          # have always done to narrow a parent's rules. Declaring a different
          # scope adds to them.
          self.petergate_rules = petergate_rules
            .merge(key => Petergate::Rule.new(
              scope: scope, rules: rules.freeze, message: message, defaulted: defaulted
            ))
            .freeze

          install_petergate_callback!
        end

        # Deprecated. petergate's own callback no longer calls these, but
        # applications may. Kept quiet deliberately: the suite raises on any
        # ActiveSupport deprecation.
        def controller_rules
          rule = petergate_rules[Petergate::DEFAULT_SCOPE] ||
                 petergate_rules[petergate_default_scope] ||
                 petergate_rules.values.first
          rule&.rules || {}
        end

        def controller_message
          petergate_rules.each_value.map(&:message).compact.first || "Permission Denied"
        end

        private
          # A class that is not a model can never be a scope: there is no name to
          # derive a helper from, so it resolves to :user, the exact type check
          # then refuses every role rule, and `all:` rules keep granting -- all
          # silently. Refuse it where it is declared instead.
          def petergate_validate_scope!(scope)
            # To `access` a String is the denial message. Accepting one here as
            # a scope name would make the same literal mean two different things
            # depending on which declaration it landed in, so a typo would be
            # silently absorbed by whichever it hit. Symbols name scopes.
            if scope.is_a?(::String)
              raise ArgumentError, "petergate_scope takes a model class or a symbol, not the " \
                                   "string #{scope.inspect}. Write `petergate_scope " \
                                   ":#{scope}` -- to `access`, a string is the denial message."
            end

            return unless scope.is_a?(::Class)
            return if scope.respond_to?(:model_name)

            raise ArgumentError, "#{scope} cannot be a petergate scope: it is not a model, " \
                                 "so there is no `current_...` to authorize against."
          end

          # Rules belong to the class that declared them. The first `access` in
          # a class discards whatever it inherited; later ones in the same class
          # add to it.
          def petergate_claim_rules!
            return if petergate_rules_owner == self

            self.petergate_rules_owner = self
            self.petergate_rules = {}.freeze
          end

          def petergate_action_names(methods)
            own         = public_instance_methods(false).map(&:to_sym)
            view_helper = respond_to?(:_helper_methods) ? _helper_methods.map(&:to_sym) : []

            methods.to_a.map(&:to_sym).select { |name|
              # What cannot be an action, whoever declared it. Rails dispatches
              # actions by name with no arguments, and predicates and bang
              # methods -- `authenticate_<scope>!` among them -- are not actions
              # by convention.
              next false if name.to_s.end_with?("?", "!")

              method = begin
                         instance_method(name)
                       rescue NameError
                         nil
                       end
              next false if method.nil?
              next false if method.parameters.any? { |type, _| type == :req || type == :keyreq }

              # Past those, a method the controller declares itself is an action
              # even when it is also registered as a helper, so an action may
              # share a name with one.
              next true if own.include?(name)

              !view_helper.include?(name)
            } - [:check_access, :title]
          end

          # Exactly one callback, however many `access` calls a controller makes.
          #
          # One per call would AND them together -- each denying on its own --
          # which is the opposite of what several scopes on one controller mean.
          # The flag is a class_attribute, so a subclass that calls `access`
          # again does not install a second copy; the inherited callback reads
          # the subclass's own rules at request time.
          #
          # Registered here rather than at include time so it lands at the
          # position of the `access` call, keeping the ordering apps rely on
          # when an earlier before_action sets up what petergate reads. A named
          # method rather than a block, so `skip_before_action` can reach it.
          # Registered at the position of the `access` call that declared the
          # rules, for every class that declares them -- not just the first in a
          # hierarchy. A subclass that sets up its own authentication and then
          # declares `access` wants petergate to run after that setup:
          #
          #     class Api::BaseController < ApplicationController
          #       before_action :authenticate_from_token
          #       access admin: :all
          #     end
          #
          # The declaring class is tracked rather than the chain inspected: the
          # filter is inherited, so it is always already present and inspecting
          # the chain can only ever leave it at the ancestor's position.
          # Skipping first keeps it to a single registration, and `raise: false`
          # because a class that never inherited it has nothing to skip.
          def install_petergate_callback!
            return if petergate_callback_owner == self

            self.petergate_callback_owner = self
            skip_before_action :petergate_check_access!, raise: false
            before_action :petergate_check_access!
          end
      end

      ALLRESTDEP = [:show, :index, :new, :edit, :update, :create, :destroy]

      def self.included(base)
        base.extend(ClassMethods)

        # instance_accessor: false -- these are only ever read through
        # self.class, and there is no reason to put three more public methods on
        # every controller in the application.
        base.class_attribute :petergate_default_scope,      instance_accessor: false, default: :user
        base.class_attribute :petergate_rules,              instance_accessor: false, default: {}.freeze
        base.class_attribute :petergate_rules_owner,        instance_accessor: false, default: nil
        base.class_attribute :petergate_callback_owner,     instance_accessor: false, default: nil

        # user_logged_in? is documented as a view helper but was never
        # registered as one.
        base.helper_method :logged_in?, :user_logged_in?, :forbidden!, :unauthorized! if base.respond_to?(:helper_method)
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
        # Allows Array's of keys for the same hash.
        rules = rules.inject({}){|h, (k, v)| k.class == Array ? h.merge(Hash[k.map{|kk| [kk, v]}]) : h.merge(k => v) }
      end

      def permissions(rules = {all: [:index, :show], customer: [], wiring: []}, scope: nil)
        rules = parse_permission_rules(rules)
        allowances = [rules[:all]]
        resource = petergate_resource(scope || self.class.petergate_scope, strict: false)
        resource.roles.each do |role|
          allowances << rules[role]
        end if resource
        allowances.flatten.compact.include?(action_name.to_sym)
      end

      # Roles are varargs, so the scope has to be a trailing keyword. Every
      # documented call -- logged_in?(:admin, :editor) -- is unaffected.
      #
      # Defaults to the controller's own scope rather than :user, so a bare
      # logged_in?(:manager) in a view under `petergate_scope Employee` asks the
      # employee. Resolves leniently: a view should render false for an unknown
      # scope, not raise. The strict resolution is on the authorization path,
      # where silence would be a hole.
      def logged_in?(*roles, scope: nil)
        resource = petergate_resource(scope || self.class.petergate_scope, strict: false)
        # `resource &&` rather than a boolean cast: this has always returned nil
        # for a visitor, and views render that as "" where false renders "false".
        resource && resource.has_roles?(*roles)
      end

      # Note this asks the type-exact question: under `petergate_scope Employee`
      # a signed-in Manager is not an Employee, so this is false even though
      # somebody is signed in. That is deliberate, and it is a different question
      # from the one behind forbidden-vs-unauthorized, which asks whether the
      # underlying login is occupied at all.
      def user_logged_in?(scope: nil)
        !!petergate_resource(scope || self.class.petergate_scope, strict: false)
      end

      # First match wins: the message of the scope that actually refused a
      # signed-in person, then the controller's own scope, then whatever was
      # declared first.
      def custom_message
        rules = petergate_declared_rules

        petergate_signed_in_rule&.message ||
          rules.find { |rule| petergate_scope_of(rule) == self.class.petergate_scope }&.message ||
          rules.map(&:message).compact.first ||
          "Permission Denied"
      end

      def unauthorized!(scope: nil)
        # ActionController::API has no MimeResponds, so no respond_to; a bare
        # status is the right answer for an API caller regardless.
        return head(:unauthorized) if is_a?(::ActionController::API)

        respond_to do |format|
          format.any(:js, :json, :xml) do
            head(:unauthorized)
          end
          format.html do
            return petergate_authenticate!(scope || petergate_denial_scope)
          end
        end
      end

      def forbidden!(msg = nil)
        # See unauthorized! -- API controllers cannot respond_to.
        return head(:forbidden) if is_a?(::ActionController::API)

        respond_to do |format|
          format.any(:js, :json, :xml) do 
            head(:forbidden)
          end
          format.html do
            notice = msg || request.headers['msg'] || custom_message

            # The Referer is deliberately not consulted. The original line read
            # request.headers['Referrer'] -- a misspelling of the HTTP header --
            # so it was always nil and this always resolved to the signed-in
            # destination. Honouring the real header now would change where
            # every existing app sends a refused user, and would hand the
            # redirect target to the caller.
            resource = petergate_redirect_resource
            destination = resource.present? ? after_sign_in_path_for(resource) : root_path
            redirect_to destination, notice: notice
          end
        end
      end

      private
        # The single callback every `access` call feeds.
        #
        # Scopes are OR'd: each is evaluated against its own resource, and one
        # passing is enough. Private, so it can never be mistaken for an action.
        def petergate_check_access!
          rules = petergate_declared_rules
          return if rules.empty?

          # The cache lives for this check and no longer. Within it, an empty
          # scope is asked about many times -- the root_admin pass, the granting
          # pass, the denial decision, the redirect target, the message -- and
          # caching nil keeps that to one lookup. Outside it, a cached nil would
          # outlive an action that signs someone in and then renders, leaving the
          # view to draw itself for a stranger.
          @_petergate_resources = {}

          begin
            petergate_evaluate_access!(rules)
          ensure
            @_petergate_resources = nil
          end
        end

        def petergate_evaluate_access!(rules)
          # Every declared scope must have a helper behind it, whoever happens
          # to be signed in: the passes below short-circuit, so a typo would
          # otherwise raise or stay silent depending on the request.
          #
          # Existence only. Actually reading current_<scope> would have Warden
          # deserialize a session -- and possibly query -- for scopes the checks
          # may never reach.
          rules.each { |rule| petergate_assert_scope!(petergate_scope_of(rule)) }

          # root_admin bypasses, but only in a scope this controller declares.
          # Including the controller's default scope unconditionally would let a
          # root_admin User walk into a controller whose rules are all about
          # another model.
          return if rules.any? { |rule| petergate_holds_role?(petergate_scope_of(rule), :root_admin) }

          return if rules.any? { |rule| petergate_grants?(rule) }

          # Nobody passed. Whether that is "wrong person" or "no person" decides
          # between the two denials, and the answer falls out of the scope
          # rather than needing configuration: if a declared scope holds someone
          # -- signed in but the wrong type, under STI -- there is nothing
          # further to authenticate as. If every declared scope is empty, a
          # login genuinely is the answer.
          #
          # @user is honoured as a stand-in for a signed-in resource, as it
          # always has been.
          if petergate_signed_in_rule || @user
            forbidden!
          else
            unauthorized!
          end
        end

        # Every rule this controller authorizes by, and the scope each resolves
        # to here -- a rule that named no scope follows this controller's
        # petergate_scope, wherever it was declared.
        def petergate_declared_rules
          self.class.petergate_rules.values
        end

        def petergate_scope_of(rule)
          rule.scope_for(self.class)
        end

        def petergate_grants?(rule)
          rules      = parse_permission_rules(rule.rules)
          allowances = [rules[:all]]
          resource   = petergate_resource(petergate_scope_of(rule))

          resource.roles.each { |role| allowances << rules[role] } if resource
          allowances.flatten.compact.include?(action_name.to_sym)
        end

        def petergate_holds_role?(scope, *roles)
          resource = petergate_resource(scope)
          !!resource && resource.has_roles?(*roles)
        end

        # The resource for a scope, or nil when it is the wrong type.
        #
        # A Class scope matches exactly: under STI `current_user` may be any
        # subclass, and `access Employee` means an Employee, not merely something
        # descended from User. A subclass therefore has to name itself.
        def petergate_resource(scope, strict: true)
          resource = petergate_scope_resource(scope, strict: strict)
          return resource unless scope.is_a?(Class)

          resource if resource.instance_of?(scope)
        end

        # Checks that a scope resolves to a helper this controller actually has.
        # Cheap and free of side effects, so it can run for every declared scope
        # on every request.
        def petergate_assert_scope!(scope)
          method = "current_#{Petergate.devise_scope_for(scope)}"
          return if respond_to?(method, true)

          raise Petergate::MissingScopeError, petergate_missing_scope_message(method, scope)
        end

        def petergate_scope_resource(scope, strict: true)
          # Never created here. The cache is set up by petergate_check_access!
          # and torn down with it, so a lenient caller outside that window --
          # a view helper, or an app filter on a controller with no `access` at
          # all -- reads the login fresh instead of leaving a nil behind for the
          # rest of the request.
          cache = @_petergate_resources

          # Keyed by the Devise scope, not the declared one. Several classes can
          # share one login -- under STI they all do -- and they are the same
          # resource; only the type check that follows differs. Keyed by the
          # declared scope instead, `Employee` and `Staff` each cost their own
          # session lookup.
          devise_scope = Petergate.devise_scope_for(scope)
          return cache[devise_scope] if cache&.key?(devise_scope)

          method = "current_#{devise_scope}"

          # A missing helper is never recorded, so a lenient caller cannot
          # suppress the error for a later strict one.
          unless respond_to?(method, true)
            raise Petergate::MissingScopeError, petergate_missing_scope_message(method, scope) if strict
            return nil
          end

          resource = send(method)
          # nil is recorded too: within one check an empty scope is asked about
          # by every pass, and each miss would otherwise be a fresh lookup.
          cache[devise_scope] = resource if cache
          resource
        end

        # The first declared rule whose scope holds anyone at all, whatever
        # their type. This is what separates "wrong person" from "no person".
        def petergate_signed_in_rule
          petergate_declared_rules.find do |rule|
            petergate_scope_resource(petergate_scope_of(rule), strict: false)
          end
        end

        # Whom to redirect a refused person to their own home page as. Falls
        # back to the controller's scope because forbidden! is public API and
        # gets called from controllers that declare no rules at all.
        def petergate_redirect_resource
          rule = petergate_signed_in_rule
          return petergate_scope_resource(petergate_scope_of(rule), strict: false) if rule

          petergate_scope_resource(self.class.petergate_scope, strict: false)
        end

        # Which login a stranger is sent to. The controller's own scope when it
        # is one of the declared ones -- that is what `petergate_scope` is for --
        # otherwise the first scope declared, so a controller whose only rules
        # are about Employee never hands visitors a :user login.
        def petergate_denial_scope
          rules   = petergate_declared_rules
          default = self.class.petergate_scope
          scopes  = rules.map { |rule| petergate_scope_of(rule) }
          return default if scopes.empty? || scopes.include?(default)

          scopes.first
        end

        def petergate_authenticate!(scope)
          petergate_send("authenticate_#{Petergate.devise_scope_for(scope)}!", scope, strict: true)
        end

        # respond_to?/send rather than public_send: Devise's helpers are public,
        # an application's hand-written ones are often private (and should be,
        # or they look like actions). Both have to work.
        def petergate_send(method, scope, strict:)
          unless respond_to?(method, true)
            return nil unless strict

            raise Petergate::MissingScopeError, petergate_missing_scope_message(method, scope)
          end

          send(method)
        end

        # Says which of the two ways this went wrong, because they have
        # different fixes and the resolved name alone does not distinguish them.
        def petergate_missing_scope_message(method, scope)
          devise_scope = Petergate.devise_scope_for(scope)

          if scope.is_a?(Class) && devise_scope != Petergate.own_scope_name_for(scope)
            <<~MESSAGE.squish
              #{self.class.name} authorizes against #{scope}, which petergate resolved to the
              #{devise_scope.inspect} authentication scope -- but there is no ##{method}.
              If #{scope} signs in through its own login, add
              `devise_for :#{devise_scope.to_s.pluralize}` to config/routes.rb. If it shares a
              login with a parent class, that parent is what needs the login, and #{scope} only
              needs its roles. If #{scope} is not an authenticatable model at all, it cannot be
              a petergate scope.
            MESSAGE
          else
            <<~MESSAGE.squish
              #{self.class.name} authorizes against the #{scope.inspect} scope, but there is no
              ##{method}. Add `devise_for :#{devise_scope.to_s.pluralize}` to config/routes.rb,
              or define ##{method} yourself. A scope comes from `petergate_scope` or from
              the first argument to `access`.
            MESSAGE
          end
        end
    end
  end
end

# Hook in lazily rather than reopening ActionController::Base at require time:
# eager reopening forces ActionPack to load during boot, and it misses API
# controllers entirely.
#
# :action_controller rather than the newer :action_controller_base and
# :action_controller_api pair. Rails runs this one for both Base and API, and
# it predates the other two (added in 5.2) -- so on an older Rails the pair
# would simply never fire and petergate would silently stop working.
ActiveSupport.on_load(:action_controller) do
  include Petergate::ActionController::Base
end

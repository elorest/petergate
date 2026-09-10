module Petergate
  # One `access` declaration: the scope it authorizes against, the role => actions
  # rules, and the denial message set alongside them.
  #
  # `scope` is the value as written -- a Class for `access Employee`, a Symbol
  # for `access :member`. It is deliberately not resolved to a Devise scope
  # here: under STI several classes resolve to the same Devise scope, and rules
  # are keyed by what was declared so they stay distinct.
  #
  # `defaulted` marks a rule that named no scope, so it follows whatever
  # `petergate_scope` the controller reading it has. That is what makes
  # `petergate_scope` in a base controller govern rules declared above it, and
  # it is why the scope is resolved when rules are read rather than written --
  # rewriting the key at declaration time cannot see the subclasses to come, and
  # cannot tell a defaulted :user from one someone asked for by name.
  Rule = Struct.new(:scope, :rules, :message, :defaulted, keyword_init: true) do
    # The scope this rule authorizes against, for the controller reading it.
    def scope_for(controller_class)
      defaulted ? controller_class.petergate_scope : scope
    end
  end

  # The hash key a defaulted rule is filed under. A sentinel rather than the
  # current default, so it stays distinct from `access :user, ...` and cannot
  # collide with a rule declared for a named scope.
  DEFAULT_SCOPE = :"petergate.default_scope"

  # Raised when a declared scope has no authentication helper behind it, which
  # nearly always means a missing `devise_for` or a typo.
  #
  # StandardError rather than NameError: applications rescue NameError around
  # autoloading and would swallow this.
  class MissingScopeError < StandardError; end
end

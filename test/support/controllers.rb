class ApplicationController < ActionController::Base
  include TestAuthentication
end

# Rules live on a parent class to prove they are inherited by subclasses.
class InheritanceController < ApplicationController
  access all: [:index], user: [:index, :show], company_admin: { except: [:destroy] }
end

class BlogsController < InheritanceController
  def index;   render plain: "index";   end
  def show;    render plain: "show";    end
  def new;     render plain: "new";     end
  def edit;    render plain: "edit";    end
  def create;  Blog.create!(title: "t"); render plain: "create";  end
  def update;  render plain: "update";  end
  def destroy; Blog.first&.destroy;     render plain: "destroy"; end
end

# `:all` as a role's value means "every action on this controller".
class OpenController < ApplicationController
  access all: :all
  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# An array of role keys sharing one set of actions.
class SharedKeysController < ApplicationController
  access [:all, :user] => [:index]
  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# A custom denial message, as a positional string.
class PositionalMessageController < ApplicationController
  access "You shall not pass", user: [:index]
  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# The same, given the deprecated way, which still works. Defined with stderr
# silenced so its deprecation warning does not litter the suite's output; the
# warning itself is asserted in denial_test.rb.
_petergate_stderr, $stderr = $stderr, StringIO.new
class CustomMessageController < ApplicationController
  access user: [:index], message: "You shall not pass"
  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end
$stderr = _petergate_stderr

# Calls the denial helpers directly, the way an app's own before_action would.
class DirectDenialController < ApplicationController
  access all: :all

  def forbid
    forbidden! params[:msg]
  end

  def deny
    unauthorized!
  end
end

# Rules declared with a block.
class BlockRulesController < ApplicationController
  access { { all: [:index] } }
  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

class ApiBaseController < ActionController::API
  include TestAuthentication
end

class WidgetsController < ApiBaseController
  access all: [:index], company_admin: :all
  def index;   render json: { action: "index" };   end
  def destroy; render json: { action: "destroy" }; end
end

# Exposes petergate's helpers to a view, which is how `helper_method` is used.
class HelpersController < ApplicationController
  access all: :all

  def show
    render inline: "admin=<%= logged_in?(:company_admin) %> root=<%= logged_in?(:root_admin) %>"
  end
end

# Malformed rules, to pin down the errors petergate raises.
class BadSymbolRuleController < ApplicationController
  access user: :bogus
  def index; head :ok; end
end

class BadExceptRuleController < ApplicationController
  access user: { only: [:index] }
  def index; head :ok; end
end

class BadValueRuleController < ApplicationController
  access user: 42
  def index; head :ok; end
end

# A block whose return value is not a Hash must be ignored.
class BlockReturningNilController < ApplicationController
  access(all: [:index]) { nil }
  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# No access rules at all. The README shows calling forbidden! from an app's own
# before_action, which reaches the denial helpers with no declared message.
class NoRulesController < ApplicationController
  def forbid
    forbidden!
  end
end

# petergate treats @user as a stand-in for current_user when deciding between
# "forbidden" and "needs to authenticate". prepend_before_action puts it in
# place before petergate's own callback runs.
class GhostUserController < ApplicationController
  prepend_before_action { @user = MultiRoleUser.new }
  access all: [:index]

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# Auth helpers defined *publicly* on a concrete superclass. Rails' own
# `action_methods` reports these as actions -- `internal_methods` only subtracts
# up to the first abstract controller -- so `all_actions` has to reject them
# itself. This is the shape a real Devise app has whenever it overrides
# `current_user` in ApplicationController.
class PublicHelperBaseController < ActionController::Base
  include TestAuthentication

  def current_employee; nil; end
  def authenticate_employee!; nil; end
  def employee_signed_in?; false; end
  def after_sign_in_path_for(resource); "/dashboard"; end

  helper_method :current_employee if respond_to?(:helper_method)
end

class PublicHelperController < PublicHelperBaseController
  # A real action whose name collides with a Devise helper. It is declared on
  # this controller, so it must survive the filtering.
  def user_session; render plain: "user_session"; end
  def index;        render plain: "index";        end
end

################################################################################
# Scopes
################################################################################

class ScopedBaseController < ActionController::Base
  include TestAuthentication
  include ScopedAuthentication
end

# One login, rules about a subclass of it. `:viewer` exists in both Staff's and
# Employee's vocabularies, so only the scope can tell the two apart.
class EmployeeOnlyController < ScopedBaseController
  petergate_scope Employee
  access viewer: [:index], support: :all

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# The namespace default is inherited, and the subclass adds rules without
# repeating the scope.
class EmployeeChildController < EmployeeOnlyController
  access viewer: [:index, :show]

  def show; render plain: "show"; end
end

# Two scopes on one controller: satisfied independently, OR'd.
class DualScopeController < ScopedBaseController
  access Employee, viewer: [:index]
  access Staff, viewer: [:show]
  access Vendor, supplier: [:destroy]

  def index;   render plain: "index";   end
  def show;    render plain: "show";    end
  def destroy; render plain: "destroy"; end
end

# Exact matching: Manager < Employee must be named to be admitted.
class ExactMatchController < ScopedBaseController
  access Employee, viewer: [:index]
  access Manager, viewer: [:show]

  def index; render plain: "index"; end
  def show;  render plain: "show";  end
end

# Declares only a non-default scope, so a visitor must be sent to that scope's
# login rather than to :user's.
class VendorOnlyController < ScopedBaseController
  access Vendor, supplier: [:index]

  def index; render plain: "index"; end
end

# petergate_scope names which login a stranger sees when several are declared.
class VendorPrimaryController < ScopedBaseController
  petergate_scope Vendor
  access Vendor, supplier: [:index]
  access Employee, support:  [:index]

  def index; render plain: "index"; end
end

# A scope with no authentication helper behind it at all.
class MissingScopeController < ScopedBaseController
  access :nobody, supplier: [:index]

  def index; render plain: "index"; end
end

# Per-scope messages.
class ScopedMessageController < ScopedBaseController
  access Employee, "staff only",  support:  [:index]
  access Vendor,   "vendors only", supplier: [:index]

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# Scope-aware view helpers.
class ScopedHelpersController < ScopedBaseController
  petergate_scope Employee
  access all: :all

  def show
    render inline: "default=<%= logged_in?(:support) %> " \
                   "vendor=<%= logged_in?(:supplier, scope: Vendor) %> " \
                   "typo=<%= logged_in?(:support, scope: :nobody) %> " \
                   "any=<%= user_logged_in? %>"
  end
end

# A class that is not an authenticatable model at all: the other way a scope
# can have no helper behind it.
class NonAuthScopeController < ScopedBaseController
  access Blog, admin: [:index]

  def index; render plain: "index"; end
end

# GhostChild resolves to its parent's scope, which has no helper either.
class InheritedScopeController < ScopedBaseController
  access GhostChild, spectre: [:index]

  def index; render plain: "index"; end
end

# A parent whose rules are about :user, and a child that names a different
# scope. The child must not inherit the parent's grant -- OR-ing them would let
# any signed-in :user reach everything under the child.
class WideParentController < ScopedBaseController
  access all: [:index], company_admin: :all
end

class NarrowChildController < WideParentController
  petergate_scope Employee
  access support: :all

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# `petergate_scope` written after `access`, which must still file the rule
# under the named scope.
class LateScopeController < ScopedBaseController
  access support: [:index]
  petergate_scope Employee

  def index; render plain: "index"; end
end

# A lenient lookup runs first, in an app's own filter, before petergate's check.
class LenientFirstController < ScopedBaseController
  prepend_before_action { logged_in?(:whatever, scope: :nobody) }
  access :nobody, admin: [:index]

  def index; render plain: "index"; end
end

# petergate_scope on a base controller must govern rules declared *above* it.
# Nothing here calls `access`, so the rules are ApplicationController-style ones
# that named no scope, and they have to follow this tree's scope.
class ScopedTreeBaseController < ScopedBaseController
  access all: [:index], company_admin: :all
end

class ScopedTreeStaffController < ScopedTreeBaseController
  petergate_scope Employee

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# A named scope and a defaulted one must coexist; declaring petergate_scope
# afterwards must not clobber the named rule.
class TwoScopeKindsController < ScopedBaseController
  access Vendor, supplier: [:index]
  access support: [:show]
  petergate_scope Employee

  def index; render plain: "index"; end
  def show;  render plain: "show";  end
end

# An explicit :user rule is not the defaulted one, and must stay :user.
class ExplicitUserScopeController < ScopedBaseController
  access :user, company_admin: [:index]
  petergate_scope Employee

  def index; render plain: "index"; end
end

# A filter that signs someone in after petergate has already looked leniently.
class LateSignInController < ScopedBaseController
  prepend_before_action do
    logged_in?(:anything)                       # populates the lookup with nil
    Petergate::Session.resources[:user] = MultiRoleUser.find_by(email: "late@example.com")
  end
  access company_admin: [:index]

  def index; render plain: "index"; end
end

# skip_before_action, then a grandchild declaring its own rules. The flag that
# used to guard installation was inherited, so the grandchild ended up with
# rules that nothing enforced.
class SkipParentController < ScopedBaseController
  access all: :all
end

class SkipMiddleController < SkipParentController
  skip_before_action :petergate_check_access!
end

class SkipChildController < SkipMiddleController
  access company_admin: :all

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# A scope whose helper does not exist, declared *after* one that can be
# satisfied. The checks short-circuit, so the typo must still be reported.
class TypoAfterGrantController < ScopedBaseController
  access Vendor, supplier: [:index]
  access :vendors, admin: [:index]

  def index; render plain: "index"; end
end

# A subclass that sets up its own authentication and then declares rules. The
# callback has to land after that filter, or petergate looks before there is
# anyone to find. On 3.1.1 the parent's callback ran first and denied.
class TokenBaseController < ActionController::Base
  include TestAuthentication
  access all: [:index]
end

class TokenChildController < TokenBaseController
  before_action :authenticate_from_token
  access company_admin: :all

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end

  private
    def authenticate_from_token
      Petergate::Session.resources[:user] = MultiRoleUser.find_by(email: "token@example.com")
    end
end

# Signs someone in during the action and then renders, rather than redirecting.
class MidActionSignInController < ApplicationController
  access all: :all

  def show
    Petergate::Session.resources[:user] = MultiRoleUser.find_by(email: "mid@example.com")
    render inline: "any=<%= user_logged_in? %> admin=<%= logged_in?(:company_admin) %>"
  end
end

# A public method the controller declares itself that still cannot be an action.
class OwnArgumentController < ApplicationController
  access all: :all

  def index; render plain: "index"; end
  def after_sign_in_path_for(resource); "/dashboard"; end
end

# A scope with a `current_` helper but no `authenticate_` one. Only the HTML
# denial path calls the authenticator, so a granted request -- and any
# webservice request -- has to work without it.
class RobotApiController < ApiBaseController
  access :robot, all: [:index], company_admin: [:destroy]

  def index;   render json: { action: "index" };   end
  def destroy; render json: { action: "destroy" }; end

  private
    def current_robot; Petergate::Session.resources[:robot]; end
end

# The same gap on an HTML controller, where the visitor path does reach the
# authenticator and so must still report it.
class DroidController < ApplicationController
  access :droid, company_admin: [:index]

  def index; render plain: "index"; end

  private
    def current_droid; Petergate::Session.resources[:droid]; end
end

# No access declaration, so petergate's callback never runs. An app filter
# peeks leniently before a later one signs someone in.
class NoRulesPeekController < ApplicationController
  before_action :peek
  before_action :sign_in_from_token

  def show; render inline: "any=<%= user_logged_in? %>"; end

  private
    def peek; logged_in?; end

    def sign_in_from_token
      Petergate::Session.resources[:user] = MultiRoleUser.find_by(email: "peek@example.com")
    end
end

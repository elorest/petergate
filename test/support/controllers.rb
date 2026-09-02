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

# A custom denial message.
class CustomMessageController < ApplicationController
  access user: [:index], message: "You shall not pass"
  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

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

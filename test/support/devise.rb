# A real Devise model, and a controller that takes its authentication from
# Devise rather than from the stub in support/authentication.rb. This is the
# only place the suite depends on Devise, and it exists to prove that the
# three methods the README asks for line up with what Devise actually provides.
class User < ActiveRecord::Base
  devise :database_authenticatable, :validatable

  petergate(roles: [:root_admin, :company_admin], multiple: true)
end

class DeviseBackedController < ActionController::Base
  access all: [:index], company_admin: :all

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# An STI subclass of the Devise model. It has no mapping of its own, so it
# shares `current_user`, and petergate has to narrow by type instead. This is
# the shape `Petergate.devise_scope_for` resolves through Devise's mappings.
class Approver < User
  petergate(roles: [:root_admin, :approver], multiple: true)
end

# A separately mapped Devise model: its own `devise_for`, so its own scope and
# its own `current_supplier`.
class Supplier < ActiveRecord::Base
  devise :database_authenticatable, :validatable

  petergate(roles: [:root_admin, :shipping], multiple: true)
end

# Rules about the STI subclass, resolved against Devise's :user mapping.
class DeviseStiController < ActionController::Base
  access Approver, approver: :all

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# Rules about the separately mapped model, resolved to its own scope.
class DeviseSupplierController < ActionController::Base
  access Supplier, shipping: :all

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

# Both at once, OR'd, with real Devise sessions on each side.
class DeviseBothScopesController < ActionController::Base
  access Approver, approver: [:index]
  access Supplier, shipping: [:destroy]

  def index;   render plain: "index";   end
  def destroy; render plain: "destroy"; end
end

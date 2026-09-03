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

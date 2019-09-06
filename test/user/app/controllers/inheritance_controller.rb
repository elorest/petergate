class InheritanceController < ApplicationController
  access all: [:index], user: [:index, :show], company_admin: {except: [:destroy]}
end

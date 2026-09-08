Rails.application.routes.draw do
  if DEVISE_AVAILABLE
    devise_for :users
    devise_for :suppliers
  end

  root to: "blogs#index"
  resources :blogs

  get "/sign_in",   to: "blogs#index", as: :sign_in
  get "/dashboard", to: "blogs#index", as: :dashboard

  %w[open shared_keys custom_message positional_message block_rules block_returning_nil ghost_user].each do |name|
    get    "/#{name}",   to: "#{name}#index",   as: name
    delete "/#{name}/1", to: "#{name}#destroy", as: "#{name}_destroy"
  end

  get "/forbid", to: "direct_denial#forbid"
  get "/deny",   to: "direct_denial#deny"

  get "/helpers", to: "helpers#show"
  get "/no_rules_forbid", to: "no_rules#forbid"

  get "/bad_symbol", to: "bad_symbol_rule#index"
  get "/bad_except", to: "bad_except_rule#index"
  get "/bad_value",  to: "bad_value_rule#index"

  get    "/devise_backed",   to: "devise_backed#index"
  delete "/devise_backed/1", to: "devise_backed#destroy"

  if DEVISE_AVAILABLE
    %w[devise_sti devise_supplier devise_both_scopes].each do |name|
      get    "/#{name}",   to: "#{name}#index",   as: name
      delete "/#{name}/1", to: "#{name}#destroy", as: "#{name}_destroy"
    end
  end

  get    "/widgets",   to: "widgets#index"
  delete "/widgets/1", to: "widgets#destroy"

  get "/vendor_sign_in", to: "blogs#index", as: :vendor_sign_in
  get "/staff_sign_in",  to: "blogs#index", as: :staff_sign_in

  %w[employee_only employee_child dual_scope exact_match vendor_only
     vendor_primary missing_scope scoped_message non_auth_scope
     inherited_scope narrow_child late_scope lenient_first
     scoped_tree_staff two_scope_kinds explicit_user_scope late_sign_in
     skip_child typo_after_grant token_child].each do |name|
    get    "/#{name}",   to: "#{name}#index",   as: name
    get    "/#{name}/s", to: "#{name}#show",    as: "#{name}_show"
    delete "/#{name}/1", to: "#{name}#destroy", as: "#{name}_destroy"
  end

  get    "/robot_api",   to: "robot_api#index"
  delete "/robot_api/1", to: "robot_api#destroy"
  get    "/droid",       to: "droid#index"
  get    "/no_rules_peek", to: "no_rules_peek#show"

  get "/scoped_helpers", to: "scoped_helpers#show"
  get "/mid_action_sign_in", to: "mid_action_sign_in#show"
end

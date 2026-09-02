Rails.application.routes.draw do
  root to: "blogs#index"
  resources :blogs

  get "/sign_in",   to: "blogs#index", as: :sign_in
  get "/dashboard", to: "blogs#index", as: :dashboard

  %w[open shared_keys custom_message block_rules block_returning_nil ghost_user].each do |name|
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

  get    "/widgets",   to: "widgets#index"
  delete "/widgets/1", to: "widgets#destroy"
end

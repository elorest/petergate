[![Petergate](https://raw.githubusercontent.com/elorest/petergate/master/assets/petergate.png)](https://github.com/elorest/petergate)

[![CI](https://github.com/elorest/petergate/actions/workflows/ci.yml/badge.svg)](https://github.com/elorest/petergate/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/petergate.svg)](http://badge.fury.io/rb/petergate)



> If you like the straight forward and effective nature of [Strong Parameters](https://github.com/rails/strong_parameters) and suspect that [cancan](https://github.com/ryanb/cancan) might be overkill for your project then you'll love [Petergate's](https://github.com/elorest/petergate) easy to use and read action and content based authorizations.
>
> -- <cite>1 Peter 3:41</cite>

Requirements
------
Rails 7.1 through 8.1 on Ruby 3.2 through 3.4 are covered by CI. Older Rails
versions are permitted by the gemspec but are not verified.

Installation
------
##### Get the gem
Add this line to your application's Gemfile:

    gem 'petergate'

And then execute:

    bundle

Or install it yourself as:

    gem install petergate

##### Prerequisites: Setup Authentication (Devise)

The generator writes into `app/models/user.rb`, so a model named `User` is the
supported setup.

If you're using [devise](https://github.com/heartcombo/devise) you're in luck,
otherwise you'll have to add the following methods to your project:

    current_user
    after_sign_in_path_for(current_user)
    authenticate_user!

You also need a `root` route: a refused visitor who isn't signed in is sent
there.

##### Run the generators

    rails g petergate:install
    rake db:migrate

This will add a migration and insert petergate into your User model.

Usage
------
#### User Model

Configure available roles by modifying this block at the top of your user.rb.

```ruby
############################################################################################
## PeterGate Roles                                                                        ##
## The :user role is added by default and shouldn't be included in this list.             ##
## The :root_admin can access any page regardless of access settings. Use with caution!   ##
## The multiple option can be set to true if you need users to have multiple roles.       ##
petergate(roles: [:admin, :editor], multiple: false)                                      ##
############################################################################################
```

With `multiple: false` the role is stored in the column as a plain string. With
`multiple: true` the roles are stored as a YAML array, so query them through the
generated scopes below rather than by matching the column directly.

##### Instance Methods

```ruby
user.role => :editor
user.roles => [:editor, :user]
user.roles=(v) #sets roles
user.available_roles => [:admin, :editor, :user]
user.has_roles?(:admin, :editor) # true if the user has any of the roles passed in
user.has_role?(:admin)           # alias of has_roles?
```
##### Class Methods

A scope is defined for each configured role, named `role_` plus the pluralized
role name:

```ruby
User.role_admins   # => users holding :admin
User.role_editors  # => users holding :editor
```

So `petergate(roles: [:admin, :teacher])` gives you `User.role_admins` and
`User.role_teachers`.

#### Controllers

Setup permissions in your controllers the same as you would for a before filter like so:

```ruby
access all: [:show, :index], user: {except: [:destroy]}, company_admin: :all

# one other option that might seem a bit weird is to put a group of roles in an array:
access [:all, :user] => [:show, :index]
```

The key is a role, or an array of roles. `all` covers everyone, including
visitors who aren't signed in. The value is one of:

| Value | Meaning |
| --- | --- |
| `[:show, :index]` | just those actions |
| `:all` | every action on the controller |
| `{except: [:destroy]}` | every action except those |

`:root_admin` is not a rule you write -- a user holding it bypasses the rules
entirely.

Rules declared on a parent controller are inherited by its subclasses, so a
single `access` line on `ApplicationController` can cover a whole app.

`access` works the same way in an `ActionController::API` controller. There a
refused request answers with a bare `403`, and an unauthenticated one with
`401`, instead of redirecting.

Inside your views you can use logged_in?(:admin, :customer, :etc) to show or hide content.

```erb
<%= link_to "destroy", destroy_listing_path(listing) if logged_in?(:admin, :customer, :etc) %>
```

`logged_in?` tests roles. To ask only whether anyone is signed in, without
caring which role they hold, use `user_logged_in?`.

If you need to access available roles within your project you can by calling:

```ruby
User::ROLES              # => [:admin, :editor, :user]
User.first.available_roles # the same list, from an instance
```

`ROLES` is a constant on the model, so it is also reachable from your own
instance methods. A subclass shares its parent's roles.

#### Denying access yourself

Two helpers are available in controllers and in views:

```ruby
forbidden!     # refuse someone who is signed in
unauthorized!  # send a visitor to authentication, via authenticate_user!
```

`forbidden!` is the one you want in your own filters:

```ruby
before_action :check_active_user

def check_active_user
  forbidden! unless current_user.active
end
```

Both answer a `js`, `json` or `xml` request with a bare `403` or `401` rather
than a redirect, and do the same in an `ActionController::API` controller,
which has no format negotiation to offer.

##### The denial message

`forbidden!` takes one for a single call, and `access` sets a default for the
whole controller:

```ruby
forbidden! "Your account is suspended"

access user: [:show, :index], message: "You shall not pass"
```

The message is resolved in this order, first match winning:

| | Source |
| --- | --- |
| 1 | the argument passed to `forbidden!` |
| 2 | an `msg` request header |
| 3 | the `message:` option on `access` |
| 4 | `"Permission Denied"` |

Note the second entry: the `msg` header is read off the request, so a caller
can replace a message you set with `message:`. It is undocumented legacy
behaviour rather than something to rely on.

#### User Admin Example Form for Multiple Roles

```slim
= form_with model: @user do |f| 
  - if @user.errors.any? 
    #error_explanation 
      h2 = "#{pluralize(@user.errors.count, "error")} prohibited this user from being saved:" 
      ul 
        - @user.errors.full_messages.each do |message| 
          li = message 
 
  .field 
    = f.label :email 
    = f.text_field :email 
  - if @user.new_record? || params[:passwd] 
    .field 
      = f.label :password 
      = f.password_field :password 
    .field 
      = f.label :password_confirmation 
      = f.password_field :password_confirmation 
  .field 
    = f.label :roles 
    = f.select :roles, @user.available_roles, {}, {multiple: true} 
  .actions = f.submit 
```

#### User Admin Example Form for Single Role Mode

```slim
= form_with model: @user do |f| 
  - if @user.errors.any? 
    #error_explanation 
      h2 = "#{pluralize(@user.errors.count, "error")} prohibited this user from being saved:" 
      ul 
        - @user.errors.full_messages.each do |message| 
          li = message 
 
  .field 
    = f.label :email 
    = f.text_field :email 
  - if @user.new_record? || params[:passwd] 
    .field 
      = f.label :password 
      = f.password_field :password 
    .field 
      = f.label :password_confirmation 
      = f.password_field :password_confirmation 
  .field 
    = f.label :role 
    = f.select :role, @user.available_roles
  .actions = f.submit 
```
Development
-------

    bundle install
    bundle exec rake test

The suite boots a small Rails application in memory rather than carrying a
dummy app. To run it against a specific Rails version:

    BUNDLE_GEMFILE=gemfiles/rails_7_1.gemfile bundle exec rake test

Credits
-------

PeterGate is written and maintained by Isaac Sloan and friends.


## Contributing

1. Fork it ( https://github.com/elorest/petergate/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

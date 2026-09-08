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

The model defaults to `User`; pass another to configure it instead. The model
has to exist already.

    rails g petergate:install Employee            # app/models/employee.rb
    rails g petergate:install Employee --table-name=staff

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

##### The `:root_admin` role

`:root_admin` is the one role name petergate treats specially. It is checked
before any rule, so a user holding it reaches every action on every controller
that uses `access`, and no rule ever names it:

```ruby
class ArticlesController < ApplicationController
  access all: [:index, :show], editor: :all
end
```

An `:editor` gets what the rule says. A `:root_admin` gets all of it too,
without appearing in the rule at all.

It is not automatic, though. Like any other role it has to be declared before
anyone can hold it, because `roles=` drops anything the model does not define:

```ruby
petergate(roles: [:root_admin, :editor], multiple: true)
```

An application that never declares it has no such bypass, which is a reasonable
choice -- it exists for the account that must never be locked out of its own
admin area, not as a convenience for ordinary administrators. Prefer a normal
role you grant explicitly; reach for `:root_admin` when you specifically want an
account no `access` rule can shut out.

Two limits. It only applies where `access` is used: a controller with no rules
has nothing to bypass. And with several authentication scopes on one controller
it counts only within the scopes that controller declares, so a `:root_admin` in
one scope cannot walk into a controller whose rules are all about another.

Rules declared on a parent controller are inherited by its subclasses, so a
single `access` line on `ApplicationController` can cover a whole app.

`access` works the same way in an `ActionController::API` controller. There a
refused request answers with a bare `403`, and an unauthenticated one with
`401`, instead of redirecting.

#### Multiple authentication models

By default every rule is about `current_user`. An application with more than one
kind of signed-in person can say which one a rule means: `petergate_scope` sets
it for a whole controller tree, and `access` takes it as a first argument for a
single rule set.

```ruby
class Staff::BaseController < ApplicationController
  petergate_scope Employee     # every controller below this authorizes employees
end

class Staff::PayrollController < Staff::BaseController
  access admin: :all, support: [:index, :show]
end

class InvoicesController < ApplicationController
  access Vendor, supplier: :all
  access Employee, admin: [:index]
end
```

The same declaration covers both ways of having several kinds of user, because
petergate reads which one you have off Devise's mappings:

| Declared | Resolves to | Reads |
| --- | --- | --- |
| an STI subclass, e.g. `Employee < User` | the parent's scope | `current_user`, required to be exactly an `Employee` |
| a separately mapped model, e.g. `Vendor` | its own scope | `current_vendor` |

Matching is exact: `access Employee` does not admit a `Manager < Employee`, so
each kind names itself. A Symbol scope -- `access :member, ...` -- names a Devise
mapping directly and does no type check, which is what you want for
`devise_for :users, singular: :member`, where no class carries the name.

Several `access` calls in one class body are **OR**'d: whichever scope is
satisfied grants the action. A subclass declaring `access` replaces everything it
inherited, so narrowing a parent's rules in a subclass still narrows them rather
than adding another way in.

The denial message is positional too -- `access Employee, "Staff only",
support: :all` -- so the rules hash holds nothing but roles, and no name is
reserved.

##### Which login a refused person sees

petergate works this out rather than asking you to configure it:

| | |
| --- | --- |
| the scope holds nobody | `unauthorized!` -- that scope's `authenticate_*!` |
| the scope holds someone of the wrong kind | `forbidden!` |

So a customer who reaches an employee-only page under STI is refused outright:
there is one login and they are already through it. A customer who reaches a
`Vendor` page is sent to the vendor login instead, because that scope really is
empty -- and with Devise they can sign in there without losing the session they
already have, since Warden keys sessions per scope.

With several scopes declared and nobody signed in to any of them, the login
comes from `petergate_scope`, or from the first scope declared if the controller
has no `petergate_scope` of its own.

If a scope has no `current_*` behind it at all, petergate raises
`Petergate::MissingScopeError` rather than failing quietly. The message says
whether the class needs a `devise_for` of its own, shares a login with a parent
class, or is not an authenticatable model at all.

Inside your views you can use logged_in?(:admin, :customer, :etc) to show or hide content.

```erb
<%= link_to "destroy", destroy_listing_path(listing) if logged_in?(:admin, :customer, :etc) %>
```

`logged_in?` tests roles. To ask only whether anyone is signed in, without
caring which role they hold, use `user_logged_in?`.

Both resolve against the controller's own scope, and both take a `scope:` to ask
about another one. Both are type-exact, so under `petergate_scope Employee` a
signed-in `Manager < Employee` answers `false` -- it asks "is an Employee signed
in", not "is anybody":

```erb
<%= link_to "Payroll", payroll_path if logged_in?(:admin, scope: Employee) %>
```

If you need to access available roles within your project you can by calling:

```ruby
User::ROLES              # => [:admin, :editor, :user]
User.first.available_roles # the same list, from an instance
```

`ROLES` is a constant on the model, so it is also reachable from your own
instance methods. A subclass shares its parent's roles unless it calls
`petergate` itself, which gives it a vocabulary of its own -- useful with single
table inheritance, where each kind of user needs different roles:

```ruby
class User < ApplicationRecord
  petergate(roles: [:customer], multiple: true)
end

class Employee < User
  petergate(roles: [:admin, :support], multiple: true)
end

Employee::ROLES # => [:admin, :support, :user]
```

`roles` only ever returns roles the record's own class defines. A role in the
column that the class does not define is ignored, and warned about once. This
matters when a record's `type` changes, or when a role is dropped from a
`petergate` declaration: the column outlives whatever wrote it, and a leftover
role must not keep granting access.

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
whole controller -- as a string before the rules:

```ruby
forbidden! "Your account is suspended"

access "You shall not pass", user: [:show, :index]
access Employee, "Staff only", support: :all
```

Like the scope, it sits outside the rules hash so it cannot be confused with a
role.

The `message:` key is deprecated. It still works and a positional string wins if
both are given, but it warns, naming the file and line to change.

The message is resolved in this order, first match winning:

| | Source |
| --- | --- |
| 1 | the argument passed to `forbidden!` |
| 2 | an `msg` request header |
| 3 | the message given to `access` (or the deprecated `message:` key) |
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

# Petergate

[![Build Status](https://travis-ci.org/elorest/petergate.svg)](https://travis-ci.org/elorest/petergate)
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/isaacsloan/petergate?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Gem Version](https://badge.fury.io/rb/petergate.svg)](http://badge.fury.io/rb/petergate)



> If you like the straight forward and effective nature of [Strong Parameters](https://github.com/rails/strong_parameters) and suspect that [cancan](https://github.com/ryanb/cancan) might be overkill for your project then you'll love [Petergate's](https://github.com/isaacsloan/petergate) easy to use and read action and content based authorizations."
>
> -- <cite>1 Peter 3:41</cite>

Installation
------
#####Get the gem
Add this line to your application's Gemfile:

    gem 'petergate'

And then execute:

    bundle

Or install it yourself as:

    gem install petergate

#####Prerequisites: Setup Authentication (Devise)

Make sure your user model is defined in
    app/models/user.rb
and called User.

If you're using [devise](https://github.com/plataformatec/devise) you're in luck, otherwise you'll have to add following methods to your project:

    user_signed_in?
    current_user
    after_sign_in_path_for(current_user)
    authenticate_user!

#####Run the generators

    rails g petergate:install
    rake db:migrate

This will add a migration and insert petergate into your User model.

Usage
------
####User Model

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

##### Instance Methods

```ruby
user.role => :editor
user.roles => [:editor, :user]
user.roles=(v) #sets roles
user.available_roles => [:admin, :editor]
user.has_roles?(:admin, :editors) # returns true if user is any of roles passed in as params.
```
##### Class Methods

`User.#{role}_editors => #list of editors. Method is created for all roles. Roles [admin, :teacher] will have corresponding methods role_admins, role_teachers, etc.`

####Controllers

Setup permissions in your controllers the same as you would for a before filter like so:

```ruby
access all: [:show, :index], user: {except: [:destroy]}, company_admin: :all

# one other option that might seem a bit weird is to put a group of roles in an array:
access [:all, :user] => [:show, :index]
```

Inside your views you can use logged_in?(:admin, :customer, :etc) to show or hide content.

```erb
<%= link_to "destroy", destroy_listing_path(listing) if logged_in?(:admin, :customer, :etc) %>
```

If you need to access available roles within your project you can by calling:

```ruby
User::ROLES
# or from an instance
User.first.available_roles
# ROLES is a CONSTANT and will still work from within the User model instance methods
# like in this default setter:

def roles=(v)
  self[:roles] = v.map(&:to_sym).to_a.select{|r| r.size > 0 && ROLES.include?(r)}
end
```
If you need to deny access you can use the forbidden! method:

```ruby
before_action :check_active_user

def check_active_user
  forbidden! unless current_user.active
end
```
If you want to change the `permission denied` message you can add to the access line:

```ruby
access user: [:show, :index], message: "You shall not pass"
```

Credits
-------

PeterGate is written and maintaned by Isaac Sloan and friends.

Currently funded and maintained by [RingSeven](http://ringseven.com)


## Contributing

1. Fork it ( https://github.com/isaacsloan/petergate/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# Petergate

[![Build Status](https://travis-ci.org/isaacsloan/petergate.svg)](https://travis-ci.org/isaacsloan/petergate)
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/isaacsloan/petergate?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)


> "If you like the straight forward and effective nature of [Strong Parameters](https://github.com/rails/strong_parameters) and suspect that [cancan](https://github.com/ryanb/cancan) might be overkill for your project then you'll love [Petergate's](https://github.com/isaacsloan/petergate) easy to use and read action and content based authorizations."
>
> -- <cite>I proclaim optimistically</cite>

Installation
------

######Add this line to your application's Gemfile:

    gem 'petergate'

######And then execute:

    bundle

######Or install it yourself as:

    gem install petergate
######Setup Authentication

Make sure your user model is defined in
    app/models/user.rb
and called User.

If you're using [devise](https://github.com/plataformatec/devise) you're in luck, otherwise you'll have to add following methods to your project:

    user_signed_in?
    current_user
    after_sign_in_path_for(current_user)
    authenticate_user!

######Finally you can run the generators

    rails g petergate:install
    rake db:migrate

This will add: 
```ruby
petergate(roles: [:admin])
```
to your User model. 

Usage
------

Setup permissions in your controllers the same as you would for a before filter like so:

```ruby
access all: [:show, :index], user: AllRest
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
# ROLES is a CONSTANT and will still work from within the User model instance methods like in this default setter:

def roles=(v)
  self[:roles] = v.map(&:to_sym).to_a.select{|r| r.size > 0 && ROLES.include?(r)}
end
```


Credits
-------

PeterGate is written and maintaned by Isaac Sloan and friends.

Currently funded and maintained by [RingSeven](http://ringseven.com)

![RingSeven](https://avatars1.githubusercontent.com/u/8309133?v=3&s=200)


## Contributing

1. Fork it ( https://github.com/isaacsloan/petergate/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# Petergate

Easy to use and read action and content based authorizations.

Installation
------

Add this line to your application's Gemfile:

    gem 'petergate'

And then execute:

    bundle

Or install it yourself as:

    gem install petergate
Make sure you already have a User model setup. Works great with [devise](https://github.com/plataformatec/devise).

Run generator to install it.

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
# or
User.available_roles
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

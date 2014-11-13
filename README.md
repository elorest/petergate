# Petergate

Simple User Authorizations.

## Installation

Add this line to your application's Gemfile:

    $ gem 'petergate'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install petergate
Make sure you already have a User model setup. Works great with [devise](https://github.com/plataformatec/devise).

Run generator to install it.

    $ rails g petergate:install
    $ rake db:migrate

This will add: 
```ruby
petergate(roles: [:admin])
```
to your gem file. 

## Usage

Setup permissions in your controllers the same as you would for a before filter like so:

```ruby
access all: [:show, :index], user: AllRest
```

Inside your views you can use logged?(:admin, :customer) to show or hide content.

```erb
<%= link_to "destroy", destroy_listing_path(listing) if logged_in?(:admin) %>
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/petergate/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

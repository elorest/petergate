source "https://rubygems.org"

# Declares the runtime dependencies.
gemspec

# The default development target. gemfiles/ holds the CI matrix across the
# supported Rails versions. The suite boots a minimal Rails app instead of a
# dummy app, so it needs the full framework plus a database to talk to.
gem "rails",   "~> 8.1"
gem "sqlite3", "~> 2.0"
gem "rake",    ">= 13.0"

# Devise is not a dependency of the gem -- petergate only needs the three
# authentication methods the README documents. It is here so one test can prove
# a real Devise app satisfies that contract.
gem "devise"

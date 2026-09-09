# Changelog

## 3.2.0 (unreleased)

### Breaking

Three things behave differently for code that already exists. All three can
only take access away, never grant it, and each fails visibly when it bites --
a denial, not a silently widened door.

That is the reason this is 3.2.0 rather than 4.0.0. An upgrade cannot quietly
let someone in who was previously refused; the worst case is a refusal that
has to be put right, which is the direction an authorization library should
fail in.

- **An application whose stored roles have drifted from its declared ones will
  see those roles stop granting access.** That means a role left behind by an
  STI `type` change, or one removed from a `petergate` declaration while rows
  still carry it. See `roles` under Changed.

  Roles written through `roles=` or `role=` are unaffected. Reaching this needs
  a value the setter never wrote -- from `update_column`, raw SQL, a fixture or
  an import.

- **A subclass that declares `access` now runs petergate's check at its own
  position in the callback chain**, not the parent's. Work in a `before_action`
  declared above it now runs before the denial rather than after. See
  `petergate_check_access!` under Changed.

- **`:all` and `except:` cover fewer methods**, because `all_actions` no longer
  counts things that were never actions. An application whose rules were
  granting one of those was granting a method nobody can route to. See
  `all_actions` under Changed.

### Added

- `access` can authorize against a model other than `User`. A controller names
  the model with `petergate_scope`, inherited by its subclasses, or a single
  rule set names one as `access`'s first argument:

  ```ruby
  class Staff::BaseController < ApplicationController
    petergate_scope Employee
  end

  class InvoicesController < ApplicationController
    access Vendor, supplier: :all
    access Employee, admin: [:index]
  end
  ```

  One declaration covers both ways an application has several kinds of user:
  a subclass sharing one login through single table inheritance, and a
  separately authenticated model with a login of its own. Which one is in play
  is resolved from Devise's mappings at request time rather than configured.

  Several `access` calls in one class body are OR'd -- whichever scope is
  satisfied grants the action. A subclass declaring `access` replaces everything
  it inherited, exactly as before, so narrowing a parent's rules in a subclass
  still narrows them rather than adding an alternative way in.

  Type matching is exact: `access Employee` does not admit a `Manager < Employee`.

- The denial message can be given as a string before the rules --
  `access "Staff only", admin: :all` -- so it too is out of the rules hash.

- `logged_in?` and `user_logged_in?` take a `scope:` keyword. Both default to
  the controller's own scope.

- The install generator takes a model name: `rails g petergate:install Employee`,
  with an optional `--table-name`. With no argument its output is unchanged.

- `Petergate::MissingScopeError`, raised when a declared scope has no
  authentication helper behind it, rather than failing quietly.

### Changed

- **`roles` now returns only roles the record's own class defines.** `roles=`
  has always filtered against `available_roles`, but the reader did not, so a
  role left in the column by an STI `type` change -- or by a role being dropped
  from a `petergate` declaration -- kept authorizing. This closes that without a
  migration. Each ignored role is warned about once, naming the class and the
  role.

  Roles set through `roles=` or `role=` are unaffected, in either storage mode.
  A multi-role column holding *strings* rather than symbols is rejected rather
  than normalized, so this cannot start granting a role that previously matched
  nothing -- see Breaking.

- `all_actions` returns only actions. Rails' `action_methods` includes public
  methods inherited from a concrete superclass, so overriding `current_user` in
  `ApplicationController` -- or using `devise_group` -- put those names into
  `:all` and `except:` rules as though they were actions. It is now memoized
  against Rails' own `action_methods`, making it faster than before the fix.

- **petergate's check runs at the position of the `access` call that declared
  the rules**, for every class that declares them, and there is now exactly one
  callback however many times `access` is called.

  On 3.1.1 a parent and a subclass each declaring `access` registered two, and
  the parent's ran first -- so a request was refused before any `before_action`
  the subclass declared had run. That made `access` unusable in a subclass that
  has to set its own authentication up first:

  ```ruby
  class Api::BaseController < ApplicationController
    before_action :authenticate_from_token
    access admin: :all                      # now runs after the token lookup
  end
  ```

  An application relying on the old ordering -- an early filter written knowing
  petergate had already refused anonymous requests -- should move that filter
  below the `access` call. The callback is a named method rather than a block,
  so `skip_before_action :petergate_check_access!` can also reach it, which it
  could not before.

### Deprecated

- `controller_rules` and `controller_message` as a way to reach the rules.
  petergate's own callback no longer calls either, and neither can describe a
  controller with more than one scope: `controller_rules` returns a single
  rule's hash, so an application still calling
  `permissions(self.class.controller_rules)` from its own filter checks one
  scope of several without saying so. Declare the rules with `access` and let
  petergate evaluate them.

- `message:` inside the `access` rules hash. Pass the message as a string before
  the rules instead. The key still works, though a positional string wins when
  both are given, but it warns, naming the file and line to change.

### Fixed

- `user_logged_in?` is registered as a view helper. It has always been
  documented as one, but calling it from a view raised `NoMethodError`.

- The install generator no longer sleeps for a second per run.

## 3.1.1 and earlier

Not recorded here; see the commit history.

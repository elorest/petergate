class Blog < ActiveRecord::Base
end

# The two petergate storage modes.
class MultiRoleUser < ActiveRecord::Base
  petergate(roles: [:root_admin, :company_admin], multiple: true)
end

class SingleRoleUser < ActiveRecord::Base
  petergate(roles: [:root_admin, :company_admin], multiple: false)
end

# A second petergate model. Each model must get its own ROLES constant rather
# than deferring to whichever one happened to be loaded first.
class Account < ActiveRecord::Base
  petergate(roles: [:supervisor], multiple: false)
end

# Configuring the same model twice must not clobber the first ROLES.
class TwiceConfigured < ActiveRecord::Base
  self.table_name = "accounts"
  petergate(roles: [:first_role], multiple: false)
  petergate(roles: [:second_role], multiple: false)
end

# A subclass shares its parent's roles.
class InheritedRoles < MultiRoleUser
end

# An STI hierarchy sharing one table and one login, where each kind carries its
# own role vocabulary. Note :viewer appears in more than one: that overlap is
# exactly what a scope has to separate, since the role name alone cannot.
class Staff < ActiveRecord::Base
  self.table_name = "staff"
  petergate(roles: [:customer, :viewer], multiple: true)
end

class Employee < Staff
  petergate(roles: [:root_admin, :support, :viewer], multiple: true)
end

# A further subclass, to pin exact matching: an Employee rule must not admit a
# Manager unless the Manager is named.
class Manager < Employee
  petergate(roles: [:support, :viewer], multiple: true)
end

# Authenticated separately -- a scope of its own, not :user.
class Vendor < ActiveRecord::Base
  petergate(roles: [:root_admin, :supplier], multiple: true)
end

# An STI pair with no authentication behind it, to exercise the branch of the
# missing-scope message about sharing a parent's login.
class Ghost < ActiveRecord::Base
  self.table_name = "accounts"
  petergate(roles: [:spectre], multiple: false)
end

class GhostChild < Ghost
  petergate(roles: [:spectre], multiple: false)
end

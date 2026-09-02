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

# A subclass inherits its parent's roles...
class InheritedRoles < MultiRoleUser
end

# ...unless it configures its own.
class OwnRoles < MultiRoleUser
  petergate(roles: [:auditor], multiple: true)
end

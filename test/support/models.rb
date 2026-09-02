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

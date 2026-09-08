# The authentication contract petergate expects from the host application.
# Devise supplies these three methods in a real app; the suite supplies them
# directly so the tests exercise petergate rather than Devise.
#
# They are private so they stay out of `action_methods`, which petergate reads
# to expand `:all` and `except:` rules into concrete action names.
module TestAuthentication
  private
    def current_user
      Petergate::Session.current_user
    end

    def authenticate_user!
      redirect_to "/sign_in"
    end

    def after_sign_in_path_for(user)
      "/dashboard"
    end
end

# Two further scopes: the STI hierarchy rooted at Staff, and the separately
# authenticated Vendor. A real app gets these from `devise_for`; here they are
# hand-rolled, which is the other half of the contract the README documents.
# Private for the same reason as the rest.
module ScopedAuthentication
  private
    def current_staff
      Petergate::Session.resources[:staff]
    end

    def authenticate_staff!
      redirect_to "/staff_sign_in"
    end

    def current_vendor
      Petergate::Session.resources[:vendor]
    end

    def authenticate_vendor!
      redirect_to "/vendor_sign_in"
    end
end

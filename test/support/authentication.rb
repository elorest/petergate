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

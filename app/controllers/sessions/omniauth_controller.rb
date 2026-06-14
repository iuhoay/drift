class Sessions::OmniauthController < ApplicationController
  allow_unauthenticated_access

  def create
    auth = request.env["omniauth.auth"]
    return redirect_with_error if auth.blank? || auth.provider.blank? || auth.uid.blank?

    if authenticated?
      link_identity(auth)
    else
      sign_in_with(auth)
    end
  end

  def failure
    redirect_to new_session_path, alert: "Sign-in with that provider failed or was canceled."
  end

  private
    # Logged in already → attach this provider to the current account.
    def link_identity(auth)
      label = Identity.label_for(auth.provider)
      identity = Identity.find_by(provider: auth.provider, uid: auth.uid)

      if identity && identity.user_id != Current.user.id
        redirect_to account_path, alert: "That #{label} account is already linked to another user."
      else
        Identity.find_or_create_by!(provider: auth.provider, uid: auth.uid) { |i| i.user = Current.user }
        redirect_to account_path, notice: "#{label} connected."
      end
    end

    # Signed out → sign in via an existing identity, auto-link to a matching
    # verified email, or create a brand-new account.
    def sign_in_with(auth)
      user = Identity.find_by(provider: auth.provider, uid: auth.uid)&.user

      unless user
        email = auth.info&.email.to_s.downcase
        return redirect_no_email(auth) if email.blank?

        if (existing = User.find_by(email_address: email))
          return redirect_email_taken(auth) unless provider_email_verified?(auth)
          user = existing
        else
          user = User.create!(email_address: email, password: SecureRandom.base58(32), verified_at: Time.current)
        end

        Identity.create!(provider: auth.provider, uid: auth.uid, user: user)
      end

      start_new_session_for(user)
      redirect_to after_authentication_url, notice: "Signed in."
    end

    # GitHub's primary email (via the user:email scope) is verified; Google
    # reports verification explicitly. Anything else is treated as unverified.
    def provider_email_verified?(auth)
      case auth.provider
      when "github"
        true
      when "google_oauth2"
        ActiveModel::Type::Boolean.new.cast(auth.dig("extra", "raw_info", "email_verified"))
      else
        false
      end
    end

    def redirect_no_email(auth)
      redirect_to new_session_path,
        alert: "Your #{Identity.label_for(auth.provider)} account didn't share an email address, so we can't sign you in."
    end

    def redirect_email_taken(auth)
      redirect_to new_session_path,
        alert: "An account with that email already exists. Sign in with your password, then connect #{Identity.label_for(auth.provider)} from your account settings."
    end

    def redirect_with_error
      redirect_to new_session_path, alert: "We couldn't complete sign-in. Please try again."
    end
end

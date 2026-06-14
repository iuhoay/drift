class AccountsController < ApplicationController
  def show
    @user = Current.user
    @identities = @user.identities.order(:provider)
  end

  def destroy
    Current.user.destroy
    cookies.delete(:session_id)
    Current.session = nil
    redirect_to new_session_path, notice: "Your account has been deleted.", status: :see_other
  end
end

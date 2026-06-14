class Account::IdentitiesController < ApplicationController
  def destroy
    identity = Current.user.identities.find(params[:id])
    identity.destroy
    redirect_to account_path, notice: "#{identity.label} disconnected.", status: :see_other
  end
end

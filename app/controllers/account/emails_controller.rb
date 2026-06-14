class Account::EmailsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(email_params)
      if @user.saved_change_to_email_address?
        @user.update_column(:verified_at, nil)
        EmailVerificationMailer.verify(@user).deliver_later
        notice = "Email updated. Check your inbox to verify the new address."
      else
        notice = "Email updated."
      end
      redirect_to account_path, notice: notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def email_params
      params.expect(user: [ :email_address ])
    end
end

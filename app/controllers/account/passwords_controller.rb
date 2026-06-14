class Account::PasswordsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    unless @user.authenticate(params[:current_password])
      @user.errors.add(:current_password, "is incorrect")
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(password_params)
      redirect_to account_path, notice: "Password updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def password_params
      params.expect(user: [ :password, :password_confirmation ])
    end
end

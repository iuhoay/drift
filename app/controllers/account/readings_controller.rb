class Account::ReadingsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(reading_params)
      redirect_to account_path, notice: "Reading settings updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def reading_params
      params.expect(user: [ :reading_font, :reading_font_size ])
    end
end

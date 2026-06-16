class Account::ApiTokensController < ApplicationController
  def index
    @api_tokens = token_scope
  end

  def create
    # Turbo Drive ignores a 200 response to a form submission ("Form responses
    # must redirect"), so we answer with a stream that swaps the token list in
    # place. has_secure_token only reveals the plaintext value at creation, so
    # @new_token is rendered once here, then gone on the next plain GET.
    @new_token = Current.user.api_tokens.create!(name: token_name)
    @api_tokens = token_scope

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to account_api_tokens_path, notice: "Token created." }
    end
  end

  def destroy
    Current.user.api_tokens.find(params[:id]).destroy
    redirect_to account_api_tokens_path, notice: "Token revoked.", status: :see_other
  end

  private

  def token_scope
    Current.user.api_tokens.order(created_at: :desc)
  end

  def token_name
    params.dig(:api_token, :name).to_s.strip.presence || "Browser extension"
  end
end

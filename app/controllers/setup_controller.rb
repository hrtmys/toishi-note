# One-time flow for creating the first account on a fresh install; once
# any user exists, growth happens only through Admin::UsersController.
# The first account is either sole note-taking (solo) or admin-only (team).
class SetupController < ApplicationController
  allow_unauthenticated_access

  before_action :ensure_no_users_yet

  def new
    @user = User.new
    @trusted_header_available = TrustedHeaderLogin.enabled?
    @trusted_header_name = TrustedHeaderLogin.header_name
  end

  def create
    if params[:auth_mode] == "trusted_header"
      create_via_trusted_header
    else
      create_via_password
    end
  end

  private
    def ensure_no_users_yet
      redirect_to new_session_path if User.exists?
    end

    def create_via_password
      @user = User.new(params.expect(user: [ :email_address, :password, :password_confirmation ]))
      @user.role = params[:mode] == "team" ? :admin : :member

      if @user.save
        start_new_session_for(@user)
        redirect_to after_authentication_url, notice: t("setup.flash.account_created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    # A trusted reverse proxy already authenticated this request — read
    # identity off the header. Re-checks .enabled? itself rather than
    # trusting auth_mode, since the env var is the real security boundary.
    def create_via_trusted_header
      return create_via_password unless TrustedHeaderLogin.enabled?

      email_address = request.headers[TrustedHeaderLogin.header_name].presence
      return render_trusted_header_missing if email_address.blank?

      @user = if params[:mode] == "team"
        TrustedHeaderLogin.new(request).call
      else
        # Pins this one account as the account every future request signs
        # into, regardless of which verified email the header reports next
        # time — see TrustedHeaderLogin#call.
        User.create!(email_address: email_address, password: SecureRandom.base58(32), trusted_header_owner: true)
      end

      start_new_session_for(@user)
      redirect_to after_authentication_url, notice: t("setup.flash.account_created")
    end

    def render_trusted_header_missing
      @user = User.new
      @user.errors.add(:base, t("setup.trusted_header_missing"))
      @trusted_header_available = true
      @trusted_header_name = TrustedHeaderLogin.header_name
      render :new, status: :unprocessable_entity
    end
end

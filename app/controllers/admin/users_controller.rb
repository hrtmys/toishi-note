module Admin
  # Manages who can log in. Restricted to admin accounts (see User#role).
  # Inviting or rescuing a user never exposes their password to an admin —
  # both hand back a one-time password_reset_token link instead.
  class UsersController < ApplicationController
    before_action :require_admin

    def index
      @users = User.order(:registered_at)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(params.expect(user: [ :email_address ]))
      @user.password = SecureRandom.base58(32)

      if @user.save
        @invite_url = edit_password_url(@user.password_reset_token)
        render :invited
      else
        render :new, status: :unprocessable_entity
      end
    end

    def password_reset_link
      @user = User.find(params[:id])
      @reset_url = edit_password_url(@user.password_reset_token)
    end

    def destroy
      user = User.find(params[:id])

      if user == Current.user
        redirect_to admin_users_path, alert: t("admin.users.flash.cant_remove_self")
      else
        user.destroy
        redirect_to admin_users_path, notice: t("admin.users.flash.removed", email: user.email_address)
      end
    end

    private
      def require_admin
        redirect_to root_path, alert: t("admin.users.not_authorized") unless Current.user.admin?
      end
  end
end

class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user

    # deliver_later runs this in a background job with no request to
    # inherit a locale from, so the recipient's saved preference is
    # applied explicitly, covering both the subject and templates.
    I18n.with_locale(user.locale.presence || I18n.default_locale) do
      mail subject: t("passwords_mailer.reset.subject"), to: user.email_address
    end
  end
end

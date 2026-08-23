# A deliberately small Settings screen. Each preference is its own boolean
# column here (locale is the exception — a string, validated in the User
# model against I18n.available_locales).
class SettingsController < ApplicationController
  def update
    # Every other preference is a boolean that ActiveRecord just coerces;
    # locale is the first one that can fail validation, so this needs a
    # real error response instead of an unhandled 500.
    if Current.user.update(settings_params)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private
    def settings_params
      params.permit(:editor_fab_enabled, :compare_enabled, :table_paste_enabled, :keep_original_images, :locale)
    end
end

class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Declared after `include Authentication` deliberately — its before_action
  # (Current.user) must run first so this can read it.
  around_action :switch_locale

  private
    # Redirects back into Organize if that's where the request came from,
    # else +fallback+. Reads ids straight from request params so the
    # return target stays fixed regardless of what the action touched.
    def organize_or(fallback)
      return fallback unless params[:organize].present?

      root_path(organize: true, notebook_id: params[:notebook_id], folder_id: params[:folder_id], note_id: params[:note_id])
    end

    # UI copy only, never note content. I18n.with_locale (not a bare
    # assignment) scopes the change to this request, since Puma reuses
    # threads across requests.
    def switch_locale(&action)
      I18n.with_locale(current_request_locale, &action)
    end

    # Signed-in preference wins if set, else the visitor's cookie, else
    # browser detection (remembered in that cookie). A freshly detected
    # value also backfills onto Current.user if it has none yet.
    def current_request_locale
      if (user_locale = Current.user&.locale).present?
        return user_locale.to_sym
      end

      locale = cookies[:locale].presence&.to_sym
      locale = nil unless I18n.available_locales.include?(locale)
      locale ||= detect_locale_from_accept_language

      cookies.permanent[:locale] = locale.to_s
      Current.user&.update!(locale: locale.to_s)
      locale
    end

    # "ja,en-US;q=0.9,en;q=0.8" -> a browser's languages, most to least
    # preferred; picks the first one this app actually has, else
    # I18n.default_locale.
    def detect_locale_from_accept_language
      header = request.headers["Accept-Language"].to_s

      header.split(",").filter_map { |part|
        tag, quality = part.strip.split(";q=")
        next if tag.blank?

        [ tag.split("-").first.downcase.to_sym, (quality || "1.0").to_f ]
      }.sort_by { |(_, quality)| -quality }
        .map(&:first)
        .find { |language| I18n.available_locales.include?(language) } || I18n.default_locale
    end
end

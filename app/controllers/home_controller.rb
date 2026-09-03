class HomeController < ApplicationController
  def index
    # Admin accounts manage logins only — they never see the notebook UI.
    return redirect_to admin_users_path if Current.user.admin?

    # Organize is a third mode of the main pane, not a separate page —
    # it needs the same context resolved below, to render and for its
    # "back" link.
    @organize = params[:organize].present?

    @notebooks = Current.user.notebooks

    # Resolution order: the URL param, then wherever the user last left
    # off, then the first notebook. #find_by against @notebooks/@folders
    # (both Current.user-scoped) also means a stale last_folder_id from a
    # notebook other than @current_notebook is silently ignored rather
    # than leaking a folder that doesn't belong under it.
    @current_notebook = @notebooks.find_by(id: params[:notebook_id]) ||
                         @notebooks.find_by(id: Current.user.last_notebook_id) ||
                         @notebooks.first

    if @current_notebook
      @folders = @current_notebook.folders
      @current_folder = @folders.find_by(id: params[:folder_id]) ||
                         @folders.find_by(id: Current.user.last_folder_id) ||
                         @folders.first
      # Pinned-first, newest-updated-first — the default a fresh page load
      # starts from; the sidebar's sort toggle re-sorts client-side.
      @notes = @current_folder ? @current_folder.notes.order(is_pinned: :desc, updated_at: :desc) : []
    else
      @folders = []
      @current_folder = nil
      @notes = []
    end

    remember_last_position

    @current_note = Current.user.notes.find_by(id: params[:note_id])

    # last_viewed_at is pure view history — update_column, never #touch,
    # so merely reading a note doesn't bump updated_at and corrupt the
    # default sidebar order / "Updated" sort button.
    @current_note&.update_column(:last_viewed_at, Time.current)

    # Feeds the Ctrl+P palette's initial state so opening it costs no
    # round trip. reorder (not order) is needed because notebooks already
    # declares a default order scope that a plain #order would only append to.
    @palette_notes = Current.user.notes.includes(:notebook, :folder).reorder(last_viewed_at: :desc).limit(10)
  end

  private
    # update_columns, not #update: this is view history, not a user edit,
    # and it must never run a validation/callback pass on every page load.
    def remember_last_position
      return if Current.user.last_notebook_id == @current_notebook&.id &&
                Current.user.last_folder_id == @current_folder&.id

      Current.user.update_columns(last_notebook_id: @current_notebook&.id, last_folder_id: @current_folder&.id)
    end
end

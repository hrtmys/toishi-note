class HomeController < ApplicationController
  def index
    # Admin accounts manage logins only — they never see the notebook UI.
    return redirect_to admin_users_path if Current.user.admin?

    # Organize is a third mode of the main pane, not a separate page —
    # it needs the same context resolved below, to render and for its
    # "back" link.
    @organize = params[:organize].present?

    @notebooks = Current.user.notebooks

    # Use the notebook_id URL param if given, otherwise fall back to the first notebook.
    @current_notebook = @notebooks.find_by(id: params[:notebook_id]) || @notebooks.first

    if @current_notebook
      @folders = @current_notebook.folders
      @current_folder = @folders.find_by(id: params[:folder_id]) || @folders.first
      # Pinned-first, newest-updated-first — the default a fresh page load
      # starts from; the sidebar's sort toggle re-sorts client-side.
      @notes = @current_folder ? @current_folder.notes.order(is_pinned: :desc, updated_at: :desc) : []
    else
      @folders = []
      @notes = []
    end

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
end

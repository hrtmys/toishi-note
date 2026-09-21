class HomeController < ApplicationController
  def index
    # Admin accounts manage logins only — they never see the notebook UI.
    return redirect_to admin_users_path if Current.user.admin?

    # Organize and Todos are both modes of the main pane, not separate
    # pages — they need the same context resolved below, to render and
    # for their "back" link.
    @organize = params[:organize].present?
    @todos = params[:todos].present?
    @todos_view = params[:view].in?(%w[project due]) ? params[:view] : "project"

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
      # includes(:notebook): the sidebar's per-folder rename/delete forms
      # call folder.notebook for their URLs, which would otherwise be one
      # query per folder row.
      @folders = @current_notebook.folders.includes(:notebook)
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
    # round trip.
    @palette_notes = Current.user.notes.recently_viewed

    # A normal page load pays nothing for this — only the Todos mode
    # loads either query, and only the one its active view needs.
    if @todos
      if @todos_view == "due"
        @todo_items = todos_due_scope
      else
        @todo_notes = todos_project_scope
      end
    end
  end

  private
    # update_columns, not #update: this is view history, not a user edit,
    # and it must never run a validation/callback pass on every page load.
    def remember_last_position
      return if Current.user.last_notebook_id == @current_notebook&.id &&
                Current.user.last_folder_id == @current_folder&.id

      Current.user.update_columns(last_notebook_id: @current_notebook&.id, last_folder_id: @current_folder&.id)
    end

    # The "due" view's flat, cross-notebook, due-date-first list — carried
    # over verbatim from the old TodosController#index.
    def todos_due_scope
      Current.user.todo_items
        .where(is_checked: false)
        .includes(note: { folder: :notebook })
        .reorder(Arel.sql("due_date IS NULL, due_date ASC"))
    end

    # The "project" view's grouping unit: every note with at least one
    # open todo item. All its todo_items (not just open ones) are preloaded
    # so Note's loaded_* helpers avoid a COUNT query per note.
    def todos_project_scope
      open_note_ids = Current.user.todo_items.where(is_checked: false).select(:note_id)

      Current.user.notes
        .where(id: open_note_ids)
        .joins(:notebook, :folder)
        .includes(:notebook, :folder, :todo_items)
        .order("notebooks.name", "folders.name", "notes.title")
    end
end

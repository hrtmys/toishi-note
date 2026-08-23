class NotesController < ApplicationController
  def create
    folder = Current.user.folders.find(params[:folder_id])
    note_type = params.permit(:note_type)[:note_type].presence || "md"

    note = folder.notes.create!(
      notebook: folder.notebook,
      title: Note.default_title_for(note_type),
      note_type: note_type,
      content: ""
    )
    redirect_to root_path(notebook_id: folder.notebook.id, folder_id: folder.id, note_id: note.id)
  end

  def update
    @note = Current.user.notes.find(params[:id])
    old_title = @note.title # keep the pre-update title so we can detect an auto-set change below

    # An explicit title marks the note as no longer eligible for
    # auto-titling. Content-only saves never carry :title.
    update_params = note_params
    update_params = update_params.merge(title_customized: true) if update_params.key?(:title)

    if @note.update(update_params)
      # Told on every response so the client knows the version its next
      # save needs. Title/content share one lock_version, so editing
      # both quickly doesn't spuriously conflict with itself.
      response.set_header("X-Note-Lock-Version", @note.lock_version.to_s)

      respond_to do |format|
        format.turbo_stream do
          streams = []
          # Either the title was submitted explicitly, or auto_set_title changed it as a side effect.
          if note_params.key?(:title) || @note.title != old_title
            streams << turbo_stream.update("note_#{@note.id}_title", @note.title)

            # If editing the content auto-changed the title, rewrite the title input's value too.
            if note_params.key?(:content) && @note.title != old_title
              streams << turbo_stream.replace("note_title_input", partial: "notes/title_input", locals: { note: @note })
            end
          end

          if streams.any?
            render turbo_stream: streams.join
          else
            head :ok
          end
        end
        format.json { head :ok }
        # A plain form submission — the Organize view's rename control,
        # which has no existing HTML-redirect path to reuse.
        format.html { redirect_to organize_or(root_path(notebook_id: @note.notebook_id, folder_id: @note.folder_id, note_id: @note.id)) }
      end
    else
      head :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    # Rails already maps this exception to 409 by default; this rescue
    # exists to attach the current lock_version header, which a retrying
    # client needs. Conflict resolution itself is the client's job.
    response.set_header("X-Note-Lock-Version", @note.reload.lock_version.to_s)
    head :conflict
  end

  def destroy
    note = Current.user.notes.find(params[:id])
    folder_id = note.folder_id
    notebook_id = note.notebook_id
    note.destroy!
    redirect_to organize_or(root_path(notebook_id: notebook_id, folder_id: folder_id)) # back to the parent folder after deleting
  end

  def export
    note = Current.user.notes.find(params[:id])
    send_data note.to_markdown, filename: note.export_filename, type: "text/markdown"
  end

  # Drag-and-drop move — reparenting only, never a position; order stays
  # governed by pin + sort. notebook_id derives from the destination
  # folder, not the client.
  def move
    note = Current.user.notes.find(params[:id])
    target_folder = Current.user.folders.find(move_params[:target_folder_id])

    note.update!(folder: target_folder, notebook: target_folder.notebook)

    head :ok
  end

  private

  def note_params
    params.require(:note).permit(:title, :content, :is_pinned, :lock_version)
  end

  def move_params
    params.permit(:target_folder_id)
  end
end

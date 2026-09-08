class ScrapItemsController < ApplicationController
  before_action :set_note

  def create
    @item = @note.scrap_items.build(scrap_item_params)
    if @item.save
      # New scraps are always appended to the end of the list.
      render turbo_stream: turbo_stream.append("scrap_list_#{@note.id}", partial: "scrap_items/item", locals: { item: @item })
    else
      head :unprocessable_entity
    end
  end

  def update
    @item = @note.scrap_items.find(params[:id])
    if @item.update(scrap_item_params)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  def destroy
    @item = @note.scrap_items.find(params[:id])
    @item.destroy!
    render turbo_stream: turbo_stream.remove("scrap_item_#{@item.id}")
  end

  # Scrap is the temporary catch-basin, Note is the polished result — this
  # makes that workflow explicit in the UI instead of a manual copy-paste.
  def promote
    new_note = nil
    folder = nil

    ActiveRecord::Base.transaction do
      # Lock the scrap item first so a concurrent promote of the same item
      # (double-click, two tabs) serializes on it — the second request's
      # find only runs once this transaction has committed or rolled back,
      # and either finds the item already gone (RecordNotFound — the
      # existing 404 idiom for a bad id, unhandled here just like
      # everywhere else in this controller) or, if this one failed, finds
      # it unchanged and free to promote itself. (See
      # app/models/concerns/positioned.rb for why `.lock` genuinely
      # serializes here even though SQLite drops the `FOR UPDATE` SQL
      # itself.)
      @item = @note.scrap_items.lock.find(params[:id])
      folder = @note.folder

      new_note = Note.create_in_folder!(folder: folder, notebook: @note.notebook, note_type: "md", content: @item.content)
      @item.destroy!
    end

    redirect_to root_path(notebook_id: @note.notebook_id, folder_id: folder.id, note_id: new_note.id)
  end

  private

  def set_note
    @note = Current.user.notes.find(params[:note_id])
  end

  def scrap_item_params
    params.permit(:content, :source)
  end
end

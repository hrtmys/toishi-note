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
    @item = @note.scrap_items.find(params[:id])
    folder = @note.folder

    new_note = folder.notes.create!(
      notebook: @note.notebook,
      title: Note.default_title_for("md"),
      note_type: "md",
      content: @item.content
    )
    @item.destroy!

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

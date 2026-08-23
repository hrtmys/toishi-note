class FoldersController < ApplicationController
  before_action :set_notebook

  def create
    folder = @notebook.folders.create!(folder_params)
    redirect_to organize_or(root_path(notebook_id: @notebook.id, folder_id: folder.id))
  end

  def update
    folder = @notebook.folders.find(params[:id])
    folder.update!(folder_params)
    redirect_to organize_or(root_path(notebook_id: @notebook.id, folder_id: folder.id))
  end

  def destroy
    folder = @notebook.folders.find(params[:id])
    folder.destroy!
    redirect_to organize_or(root_path(notebook_id: @notebook.id))
  end

  # Drag-and-drop move: +@notebook+ scopes the lookup so a foreign folder
  # 404s. :target_notebook_id is the destination — same notebook reorders,
  # different reparents via Folder#move_to!.
  def move
    folder = @notebook.folders.find(params[:id])
    target_notebook = Current.user.notebooks.find(params[:target_notebook_id])

    folder.move_to!(target_notebook)
    Positioned.reposition!(target_notebook.folders, params[:folder_ids])

    head :ok
  end

  private

  def set_notebook
    @notebook = Current.user.notebooks.find(params[:notebook_id])
  end

  def folder_params
    params.permit(:name)
  end
end

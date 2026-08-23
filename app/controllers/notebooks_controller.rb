class NotebooksController < ApplicationController
  def create
    notebook = Current.user.notebooks.create!(notebook_params)
    redirect_to organize_or(root_path(notebook_id: notebook.id))
  end

  def update
    notebook = Current.user.notebooks.find(params[:id])
    notebook.update!(notebook_params)
    redirect_to organize_or(root_path(notebook_id: notebook.id))
  end

  def destroy
    notebook = Current.user.notebooks.find(params[:id])
    notebook.destroy!
    redirect_to organize_or(root_path)
  end

  def export
    notebook = Current.user.notebooks.find(params[:id])
    exporter = NotebookExporter.new(notebook)
    send_data exporter.to_zip, filename: exporter.filename, type: "application/zip"
  end

  # Drag-and-drop reorder of the top-level notebook list — the client
  # sends the complete post-drop id order; Positioned.reposition! reindexes
  # from it, scoped to Current.user.notebooks so a foreign id 404s.
  def reorder
    Positioned.reposition!(Current.user.notebooks, params[:notebook_ids])
    head :ok
  end

  private

  def notebook_params
    params.permit(:name)
  end
end

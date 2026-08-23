# Handles a single pasted/dropped image landing in the md editor. The
# editor inserts a grey placeholder and swaps it for the returned
# Markdown once this responds, so the response shape is deliberately tiny.
class NoteImagesController < ApplicationController
  def create
    note = Current.user.notes.find(params[:note_id])
    uploaded_file = params.require(:image)
    return head :unprocessable_entity unless uploaded_file.content_type.to_s.start_with?("image/")

    image = note.attach_uploaded_image(uploaded_file, compress: !Current.user.keep_original_images?)
    render json: { markdown: "![](#{rails_blob_path(image, only_path: true)})" }
  rescue ActionController::ParameterMissing
    head :bad_request
  end
end

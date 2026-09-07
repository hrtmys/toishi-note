# Handles a single pasted/dropped image landing in the md editor. The
# editor inserts a grey placeholder and swaps it for the returned
# Markdown once this responds, so the response shape is deliberately tiny.
class NoteImagesController < ApplicationController
  # A note attachment has no business being huge — this is a generous
  # ceiling for a pasted/dropped screenshot or photo, not a file store.
  MAX_UPLOAD_SIZE = 10.megabytes

  def create
    note = Current.user.notes.find(params[:note_id])
    uploaded_file = params.require(:image)
    return head :unprocessable_entity unless uploaded_file.content_type.to_s.start_with?("image/")
    return head :unprocessable_entity if uploaded_file.size.to_i > MAX_UPLOAD_SIZE

    image = note.attach_uploaded_image(uploaded_file, compress: !Current.user.keep_original_images?)
    render json: { markdown: "![](#{rails_blob_path(image, only_path: true)})" }
  rescue ActionController::ParameterMissing
    head :bad_request
  rescue Vips::Error
    # The client-declared content-type passed, but the bytes aren't
    # actually a decodable image (e.g. a renamed/spoofed file) — reject
    # cleanly instead of letting the decode failure surface as a 500.
    head :unprocessable_entity
  end
end

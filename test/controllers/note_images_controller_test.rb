require "test_helper"

class NoteImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "MD Note", note_type: "md")
  end

  test "attaches an uploaded image, converted to WebP by default" do
    file = fixture_file_upload("sample_image.png", "image/png")

    assert_difference("@note.images.count", 1) do
      post note_images_url(@note), params: { image: file }
    end

    assert_response :success
    blob = @note.images.last.blob
    assert_equal "image/webp", blob.content_type
    assert_match(/\.webp\z/, blob.filename.to_s)

    body = JSON.parse(@response.body)
    assert_match %r{\A!\[\]\(/rails/active_storage/blobs/}, body["markdown"]
  end

  test "keeps the original file when the uploader opted out of compression" do
    users(:one).update!(keep_original_images: true)
    file = fixture_file_upload("sample_image.png", "image/png")

    post note_images_url(@note), params: { image: file }
    assert_response :success

    blob = @note.images.last.blob
    assert_equal "image/png", blob.content_type
    assert_equal "sample_image.png", blob.filename.to_s
  end

  test "returns a bad request when no image is given" do
    post note_images_url(@note), params: {}
    assert_response :bad_request
  end

  test "rejects a non-image upload instead of trying to convert it" do
    file = fixture_file_upload("sample_image.png", "text/plain")

    assert_no_difference("@note.images.count") do
      post note_images_url(@note), params: { image: file }
    end
    assert_response :unprocessable_entity
  end

  test "only ever attaches to the current user's own note" do
    other_note = notes(:two) # belongs to users(:two)
    file = fixture_file_upload("sample_image.png", "image/png")

    post note_images_url(other_note), params: { image: file }
    assert_response :not_found
  end
end

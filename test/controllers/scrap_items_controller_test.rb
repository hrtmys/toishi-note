require "test_helper"

class ScrapItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Scrap Note", note_type: "scrap")
    @item = @note.scrap_items.create!(content: "Existing scrap")
  end

  test "should create scrap item" do
    assert_difference("ScrapItem.count") do
      post note_scrap_items_url(@note), params: { content: "New scrap" }, as: :turbo_stream
    end
    assert_response :success
  end

  test "should not create scrap item with blank content" do
    assert_no_difference("ScrapItem.count") do
      post note_scrap_items_url(@note), params: { content: "" }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end

  test "should destroy scrap item" do
    assert_difference("ScrapItem.count", -1) do
      delete note_scrap_item_url(@note, @item), as: :turbo_stream
    end
    assert_response :success
  end

  test "should update the optional source tag" do
    patch note_scrap_item_url(@note, @item), params: { source: "ChatGPT" }, as: :json
    assert_response :success
    assert_equal "ChatGPT", @item.reload.source
  end

  test "source stays optional — blank is a valid value" do
    @item.update!(source: "ChatGPT")
    patch note_scrap_item_url(@note, @item), params: { source: "" }, as: :json
    assert_response :success
    assert_equal "", @item.reload.source
  end

  test "promote turns the scrap item into an independent md note and removes it from the scrap list" do
    assert_difference("Note.count", 1) do
      assert_difference("ScrapItem.count", -1) do
        post promote_note_scrap_item_url(@note, @item)
      end
    end

    new_note = Note.order(:id).last
    assert_equal "md", new_note.note_type
    assert_equal "Existing scrap", new_note.content
    assert_equal @note.folder_id, new_note.folder_id
    assert_redirected_to root_url(notebook_id: @note.notebook_id, folder_id: @note.folder_id, note_id: new_note.id)
  end

  test "scrap actions only ever target the current user's own note" do
    other_note = notes(:two) # belongs to users(:two)
    other_item = other_note.scrap_items.create!(content: "Not mine")

    patch note_scrap_item_url(other_note, other_item), params: { source: "x" }, as: :json
    assert_response :not_found

    post promote_note_scrap_item_url(other_note, other_item)
    assert_response :not_found
  end
end

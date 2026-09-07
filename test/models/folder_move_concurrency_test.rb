require "test_helper"

# G-6 (audit): a concurrent Folder#move_to! and NotesController#create for
# a note under that folder could leave the new note with a notebook_id
# that doesn't match its own folder's actual (post-move) notebook, since
# neither path locked the folder row it was reading/writing from. Each
# thread needs its own DB connection, so transactional fixtures are off —
# the test cleans up what it creates instead.
class FolderMoveConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "a note created while its folder is mid-move never ends up with a stale notebook_id" do
    user = users(:one)
    notebook = user.notebooks.create!(name: "Origin Notebook")
    other_notebook = user.notebooks.create!(name: "Destination Notebook")
    folder = notebook.folders.create!(name: "Racing Folder")
    session_record = user.sessions.create!
    signed_session_cookie = ActionDispatch::TestRequest.create.cookie_jar.tap { |jar|
      jar.signed[:session_id] = session_record.id
    }[:session_id]

    barrier = Concurrent::CyclicBarrier.new(2)

    create_thread = Thread.new do
      barrier.wait
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.cookies["session_id"] = signed_session_cookie
      session.post "/notes", params: { folder_id: folder.id, note_type: "md" }
      session.response.status
    end
    move_thread = Thread.new do
      barrier.wait
      folder.move_to!(other_notebook)
    end
    create_status = create_thread.value
    move_thread.join

    assert_equal 302, create_status
    new_note = Note.where(folder_id: folder.id).order(:id).last
    assert_equal folder.reload.notebook_id, new_note.notebook_id, "the new note's notebook_id must match its folder's actual (post-move) notebook"
  ensure
    session_record&.destroy!
    notebook&.destroy!
    other_notebook&.destroy!
  end
end

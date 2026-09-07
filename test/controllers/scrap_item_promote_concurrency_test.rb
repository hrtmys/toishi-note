require "test_helper"

# A genuine thread-level concurrency test for G-5 (audit finding): two real
# requests racing the same "promote" action must never both create a note.
# Each thread needs its own DB connection, so transactional fixtures (which
# rely on a single shared connection/transaction per test) are turned off
# for this class — the test cleans up what it creates instead.
class ScrapItemPromoteConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  test "two concurrent promote requests for the same scrap item create only one note" do
    user = users(:one)
    notebook = user.notebooks.create!(name: "Concurrency Notebook")
    folder = notebook.folders.create!(name: "Concurrency Folder")
    note = folder.notes.create!(notebook: notebook, title: "Scrap Note", note_type: "scrap")
    item = note.scrap_items.create!(content: "Racing scrap")
    session_record = user.sessions.create!
    path = "/notes/#{note.id}/scrap_items/#{item.id}/promote"

    # Same signed cookie value sign_in_as produces, built independently per
    # thread's own session so no state is shared between the two requests.
    signed_session_cookie = ActionDispatch::TestRequest.create.cookie_jar.tap { |jar|
      jar.signed[:session_id] = session_record.id
    }[:session_id]

    barrier = Concurrent::CyclicBarrier.new(2)
    statuses = Array.new(2)

    threads = 2.times.map do |i|
      Thread.new do
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.cookies["session_id"] = signed_session_cookie
        barrier.wait # line both requests up to hit the controller as close together as possible
        session.post path
        statuses[i] = session.response.status
      end
    end
    threads.each(&:join)

    # The folder already holds the original "scrap" container note from
    # setup, so a correct single promote leaves it with exactly 2 notes —
    # the original plus the one promoted note. A second stray note from
    # the losing request would make it 3.
    assert_equal 2, Note.where(folder_id: folder.id).count, "promote must never create more than one note from the same scrap item"
    assert_not ScrapItem.exists?(item.id), "the scrap item must be gone after a successful promote"
    assert_includes statuses, 302, "at least one request must have succeeded"
  ensure
    session_record&.destroy!
    notebook&.destroy!
  end
end

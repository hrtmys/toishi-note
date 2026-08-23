require "application_system_test_case"

class ImageAttachmentsTest < ApplicationSystemTestCase
  # A minimal valid 1x1 PNG, base64-encoded — small enough to inline directly
  # in the browser-side script below rather than needing a real file input.
  SAMPLE_PNG_BASE64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Image Note", note_type: "md", notebook: @notebook)
  end

  test "dropping an image onto the editor uploads it, converted to WebP, and inserts Markdown" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    # Simulates a real drag-and-drop: builds a File from the inline base64
    # sample (decoded via atob(), not a data: URL fetch, which the app's
    # CSP doesn't permit) and dispatches a genuine DragEvent.
    page.driver.browser.execute_script(<<~JS)
      const bytes = Uint8Array.from(atob("#{SAMPLE_PNG_BASE64}"), (c) => c.charCodeAt(0))
      const file = new File([bytes], "photo.png", { type: "image/png" })
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(file)

      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new DragEvent("drop", { bubbles: true, cancelable: true })
      Object.defineProperty(event, "dataTransfer", { value: dataTransfer })
      textarea.dispatchEvent(event)
    JS

    # Capybara's `text:` filter reads rendered text nodes, not a live
    # `.value` set via JS — read the field's actual value directly instead,
    # both for the placeholder appearing and later being swapped out.
    read_value = -> { page.evaluate_script("document.querySelector(\"textarea[name='note[content]']\").value") }

    uploading_marker = I18n.t("js.image_upload.uploading", filename: "photo.png")
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.1 until read_value.call.include?(uploading_marker) }
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.1 while read_value.call.include?(uploading_marker) }

    assert_match %r{!\[\]\(/rails/active_storage/blobs/}, read_value.call

    image = @note.reload.images.first
    assert image.present?
    assert_equal "image/webp", image.blob.content_type
  end
end

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
    wait_until("image upload placeholder never appeared") { read_value.call.include?(uploading_marker) }
    wait_until("image upload never resolved to a blob URL") { !read_value.call.include?(uploading_marker) }

    assert_match %r{!\[\]\(/rails/active_storage/blobs/}, read_value.call

    image = @note.reload.images.first
    assert image.present?
    assert_equal "image/webp", image.blob.content_type
  end

  # Audit finding ux-ui #2: a failed upload used to leave a
  # `![Failed to upload x]()` marker typed into the textarea, which
  # autosave (500ms debounce) would then persist as if it were real note
  # content — permanently baking "upload failed" text into the note unless
  # the user noticed and cleaned it up by hand.
  test "a failed image upload shows a toast and never bakes a failure marker into the saved note" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    # Only the image upload request fails — autosave's own fetch must keep
    # working normally, or a false positive would come from autosave being
    # broken too rather than from the fix under test.
    page.driver.browser.execute_script(<<~JS)
      const realFetch = window.fetch.bind(window)
      window.fetch = (url, ...rest) => {
        if (String(url).includes("/images")) return Promise.reject(new TypeError("Failed to fetch"))
        return realFetch(url, ...rest)
      }
    JS

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

    assert_selector ".toast.show", text: I18n.t("js.image_upload.failed", filename: "photo.png")

    read_value = -> { page.evaluate_script("document.querySelector(\"textarea[name='note[content]']\").value") }
    assert_equal "", read_value.call

    # Give the 500ms autosave debounce (from the placeholder's own insertion,
    # before the failure even happened) time to have fired, and confirm
    # nothing ever landed in the persisted note content.
    sleep 0.7
    assert_equal "", @note.reload.content
  end
end

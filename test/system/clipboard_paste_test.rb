require "application_system_test_case"

class ClipboardPasteTest < ApplicationSystemTestCase
  TEXTAREA = "textarea[name='note[content]']".freeze
  BLOB_LINK = %r{!\[\]\(/rails/active_storage/blobs/}

  # Trimmed from a real Word paste: the <head>/<style> block is what used to leak.
  WORD_HTML = <<~HTML
    <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
    <head>
    <meta charset="utf-8">
    <meta name=ProgId content=Word.Document>
    <!--[if gte mso 9]><xml>
     <o:OfficeDocumentSettings>
      <o:AllowPNG/>
     </o:OfficeDocumentSettings>
    </xml><![endif]-->
    <style>
    <!--
     /* Font Definitions */
     @font-face
    \t{font-family:"Cambria Math";
    \tpanose-1:2 4 5 3 5 4 6 3 2 4;}
     /* Style Definitions */
     p.MsoNormal, li.MsoNormal, div.MsoNormal
    \t{margin:0cm;
    \tfont-size:10.5pt;
    \tfont-family:"游明朝",serif;}
     @page WordSection1
    \t{size:595.3pt 841.9pt;
    \tmargin:85.05pt 85.05pt 85.05pt 85.05pt;}
     div.WordSection1
    \t{page:WordSection1;}
    -->
    </style>
    </head>
    <body lang=JA style='tab-interval:21.0pt;word-wrap:break-word'>
    <div class=WordSection1>
    <p class=MsoNormal><b>Bold text</b> and normal text.<o:p></o:p></p>
    </div>
    </body>
    </html>
  HTML

  # Trimmed from a real Excel paste: plain <tr><td> rows, never a <th>.
  EXCEL_HTML = <<~HTML
    <html xmlns:x="urn:schemas-microsoft-com:office:excel">
    <head>
    <style>
    <!--table
    \t{mso-displayed-decimal-separator:"\\.";}
    td
    \t{color:black;
    \tfont-size:11.0pt;
    \tfont-family:游ゴシック, sans-serif;}
    -->
    </style>
    </head>
    <body>
    <table border=0 cellpadding=0 cellspacing=0 width=192>
     <col width=96 span=2>
     <tr height=20>
      <td height=20 class=xl65 width=96>Name</td>
      <td class=xl65 width=96>Score</td>
     </tr>
     <tr height=20>
      <td height=20 class=xl65>Alice</td>
      <td class=xl65>90</td>
     </tr>
    </table>
    </body>
    </html>
  HTML

  # A minimal valid 1x1 PNG, standing in for the rendered image Excel and Word put beside their HTML.
  SAMPLE_PNG_BASE64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

  setup do
    users(:one).update!(table_paste_enabled: true)
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Paste Note", content: "", note_type: "md", notebook: @notebook)
  end

  test "pasting and dropping into the md textarea converts Word, defers Excel to the FAB and uploads images" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    record_toasts
    converted = I18n.t("js.converted_to_markdown")
    no_pending = I18n.t("js.table_paste.no_pending_table")

    phase "1 Convert with nothing pasted" do
      click_convert
      assert_selector ".toast.show", text: no_pending
      assert_toast no_pending
      assert_equal "", textarea_value
    end

    phase "2 Word paste" do
      execute_script(<<~JS)
        window.__inputCount = 0
        document.querySelector("#{TEXTAREA}").addEventListener("input", () => { window.__inputCount += 1 })
      JS
      spy_exec_command
      result = dispatch_paste(WORD_HTML, plain_text: "Bold text and normal text.")
      assert result["prevented"], "the Word paste was not intercepted"
      calls = evaluate_script("window.__execCommandCalls")
      assert_equal 1, calls.length
      assert_equal "insertText", calls[0][0]
      assert_includes calls[0][1], "**Bold text**"
      assert_equal 1, evaluate_script("window.__inputCount"), "the insert fired more than one input event"
      assert_toast converted
      assert_no_match(/Font Definitions|mso-|WordSection1|<!--/, textarea_value)
    end

    phase "3 Shift passthrough" do
      before = textarea_value
      page.driver.browser.action.key_down(:shift).perform
      result = dispatch_paste(WORD_HTML, plain_text: "Bold text and normal text.")
      assert_not result["prevented"], "Shift+paste was still converted"
      assert_equal before, textarea_value
      assert_no_toast converted
      page.driver.browser.action.key_up(:shift).perform
      assert dispatch_paste("<p><b>x</b></p>", plain_text: "x")["prevented"], "Shift stayed held after key up"
      assert_toast converted
    end

    phase "4 plain span passthrough" do
      assert_not dispatch_paste("<span>just plain text</span>", plain_text: "just plain text")["prevented"]
      assert_no_toast converted
    end

    phase "5 Excel defers to the FAB" do
      result = dispatch_paste(EXCEL_HTML, plain_text: "Name\tScore\nAlice\t90", image: "image.png")
      assert_includes result["value"], I18n.t("js.image_upload.uploading", filename: "image.png")
      assert_no_match(/\|\s*Name\s*\|\s*Score\s*\|/, result["value"])
      assert_no_toast converted
      wait_until("the pasted image never uploaded") { textarea_value.scan(BLOB_LINK).size == 1 }
      click_convert
      assert_toast converted
      value = textarea_value
      assert_match(/\|\s*Name\s*\|\s*Score\s*\|/, value)
      assert_match(/\|\s*Alice\s*\|\s*90\s*\|/, value)
      click_convert
      assert_toast no_pending
      assert_equal value, textarea_value
    end

    phase "6 Word with an embedded picture" do
      dispatch_paste(WORD_HTML, plain_text: "Bold text and normal text.", image: "image.png")
      assert_toast converted
      assert_equal 2, textarea_value.scan("**Bold text**").size
      wait_until("the Word picture never uploaded") { textarea_value.scan(BLOB_LINK).size == 2 }
    end

    phase "7 failed then successful drop" do
      # A successful upload bumps the note's lock_version, so the earlier
      # autosaves conflict; a fresh load starts from the saved version.
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
      record_toasts
      links_before = textarea_value.scan(BLOB_LINK).size
      uploading = I18n.t("js.image_upload.uploading", filename: "photo.png")
      force_fetch_rejection(only: "/images")
      drop_image("photo.png")
      assert_toast I18n.t("js.image_upload.failed", filename: "photo.png")
      execute_script(<<~JS)
        window.__settled = null
        document.querySelector("#{TEXTAREA}").addEventListener("autosave:settled", (e) => { window.__settled = e.detail.ok }, { once: true })
      JS
      wait_until("autosave never settled after the failed upload") { !evaluate_script("window.__settled").nil? }
      assert evaluate_script("window.__settled"), "the autosave after the failed upload did not land"
      [ textarea_value, @note.reload.content ].each do |value|
        assert_not_includes value, uploading
        assert_not_includes value, "Failed"
      end

      restore_fetch
      drop_image("photo.png")
      wait_until("the dropped image never uploaded") { textarea_value.scan(BLOB_LINK).size == links_before + 1 }
      assert_equal "image/webp", @note.reload.images.last.blob.content_type
    end
  end

  private

  def textarea_value
    evaluate_script("document.querySelector(\"#{TEXTAREA}\").value")
  end

  def click_convert
    label = I18n.t("editor.fab.convert_table_paste")
    find(".editor-fab-button").click unless has_button?(label, wait: 0)
    click_on label
  end

  # Returns the value synchronously after dispatch, before an upload can replace its placeholder.
  def dispatch_paste(html, plain_text:, image: nil)
    page.driver.browser.execute_script(<<~JS, html, plain_text, image, SAMPLE_PNG_BASE64)
      const [html, plainText, image, base64] = arguments
      const dataTransfer = new DataTransfer()
      dataTransfer.setData("text/html", html)
      dataTransfer.setData("text/plain", plainText)
      if (image) {
        const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
        dataTransfer.items.add(new File([bytes], image, { type: "image/png" }))
      }
      const textarea = document.querySelector("#{TEXTAREA}")
      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
      return { prevented: event.defaultPrevented, value: textarea.value }
    JS
  end

  # Built from atob, not a data: URL fetch, which the CSP forbids.
  def drop_image(filename)
    execute_script(<<~JS, filename, SAMPLE_PNG_BASE64)
      const [filename, base64] = arguments
      const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(new File([bytes], filename, { type: "image/png" }))
      const event = new DragEvent("drop", { bubbles: true, cancelable: true })
      Object.defineProperty(event, "dataTransfer", { value: dataTransfer })
      document.querySelector("#{TEXTAREA}").dispatchEvent(event)
    JS
  end
end

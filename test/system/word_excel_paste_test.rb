require "application_system_test_case"

class WordExcelPasteTest < ApplicationSystemTestCase
  # Trimmed from a real Word paste — a <head>/<style> block (a couple of
  # lines is enough to reproduce the bug) plus a <body> with real
  # formatting. No <thead>/<th> — Word paste isn't a table.
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

  # Trimmed from a real Excel paste — plain <tr><td> rows throughout, no
  # <thead>/<th> anywhere. Excel never marks a header row; "top row = the
  # header" is an assumption this app has to make on its own.
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

  # Trimmed from a real-world paste — a merged rowspan header cell
  # leaving a cell-less <tr> behind. expandMergedCells must not
  # introduce a phantom duplicate row when filling in covered cells.
  EXCEL_ROWSPAN_HEADER_HTML = <<~HTML
    <html xmlns:x="urn:schemas-microsoft-com:office:excel">
    <body>
    <table border=0 cellpadding=0 cellspacing=0 width=140>
     <col width=70 span=2>
     <tr height=25>
      <td rowspan=2 class=xl69 width=70>group</td>
      <td rowspan=2 class=xl71 width=70>count</td>
     </tr>
     <tr height=25>
     </tr>
     <tr height=25>
      <td height=25 class=xl67 width=70>sample</td>
      <td class=xl68>18</td>
     </tr>
    </table>
    </body>
    </html>
  HTML

  # A grouped header spanning multiple columns (colspan). The header row
  # has fewer physical cells than the data rows; without expanding the
  # merge first, the mismatch misaligns every column once GFM renders it.
  EXCEL_COLSPAN_HEADER_HTML = <<~HTML
    <html xmlns:x="urn:schemas-microsoft-com:office:excel">
    <body>
    <table border=0 cellpadding=0 cellspacing=0 width=280>
     <col width=70 span=4>
     <tr height=25>
      <td colspan=2 class=xl69 width=140>Group A</td>
      <td colspan=2 class=xl69 width=140>Group B</td>
     </tr>
     <tr height=25>
      <td class=xl67 width=70>Name</td>
      <td class=xl67 width=70>Score</td>
      <td class=xl67 width=70>Name</td>
      <td class=xl67 width=70>Score</td>
     </tr>
     <tr height=25>
      <td class=xl68 width=70>Alice</td>
      <td class=xl68>90</td>
      <td class=xl68 width=70>Bob</td>
      <td class=xl68>85</td>
     </tr>
    </table>
    </body>
    </html>
  HTML

  # A full-width title row ahead of the real header row. Naive first-row
  # promotion would make that title the <thead>, showing identical title
  # text in every column instead of the real per-column labels below.
  EXCEL_TITLE_ROW_HTML = <<~HTML
    <html xmlns:x="urn:schemas-microsoft-com:office:excel">
    <body>
    <table border=0 cellpadding=0 cellspacing=0 width=140>
     <col width=70 span=2>
     <tr height=25>
      <td colspan=2 class=xl92 width=140>Summary</td>
     </tr>
     <tr height=25>
      <td class=xl67 width=70>Name</td>
      <td class=xl67 width=70>Score</td>
     </tr>
     <tr height=25>
      <td class=xl68 width=70>Alice</td>
      <td class=xl68>90</td>
     </tr>
    </table>
    </body>
    </html>
  HTML

  # A minimal valid 1x1 PNG, base64-encoded — matches the fixture used by
  # ImageAttachmentsTest — standing in for the rendered-selection image a
  # real Excel/Sheets clipboard always adds alongside the table HTML.
  SAMPLE_PNG_BASE64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Paste Note", note_type: "md", notebook: @notebook)
  end

  test "pasting real Word HTML converts to Markdown without leaking its style metadata" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    dispatch_paste(WORD_HTML, plain_text: "Bold text and normal text.")

    assert_selector ".toast.show", text: I18n.t("js.converted_to_markdown")

    value = evaluate_textarea_value
    assert_match(/\*\*Bold text\*\*/, value)
    assert_no_match(/Font Definitions|mso-|WordSection1|<!--/, value)
  end

  test "pasting an Excel range, by default, pastes the rendered image — it does not auto-convert to a table" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    # Excel/Sheets always puts a rendered image alongside the table HTML.
    # Word paste auto-converts; Excel paste deliberately does not.
    dispatch_paste_with_image(EXCEL_HTML, plain_text: "Name\tScore\nAlice\t90", image_base64: SAMPLE_PNG_BASE64)

    value = evaluate_textarea_value
    assert_includes value, I18n.t("js.image_upload.uploading", filename: "image.png")
    assert_no_match(/\|\s*Name\s*\|\s*Score\s*\|/, value)
    assert_no_selector ".toast.show", text: I18n.t("js.converted_to_markdown")
  end

  test "the FAB's Convert to Markdown button is only available once table_paste_enabled is on" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    assert_no_selector ".editor-fab-button", visible: true

    users(:one).update!(table_paste_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find(".editor-fab-button").click
    assert_selector "button", text: I18n.t("editor.fab.convert_table_paste")
    assert_no_selector "button", text: I18n.t("editor.fab.quick_formatting")
  end

  test "clicking Convert to Markdown with nothing pasted yet shows a toast instead of inserting anything" do
    users(:one).update!(table_paste_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find(".editor-fab-button").click
    click_on I18n.t("editor.fab.convert_table_paste")

    assert_selector ".toast.show", text: I18n.t("js.table_paste.no_pending_table")
    assert_equal "", evaluate_textarea_value
  end

  test "pasting an Excel range then clicking Convert to Markdown inserts the table, on top of the already-pasted image" do
    users(:one).update!(table_paste_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    dispatch_paste_with_image(EXCEL_HTML, plain_text: "Name\tScore\nAlice\t90", image_base64: SAMPLE_PNG_BASE64)
    assert_includes evaluate_textarea_value, I18n.t("js.image_upload.uploading", filename: "image.png")

    find(".editor-fab-button").click
    click_on I18n.t("editor.fab.convert_table_paste")

    assert_selector ".toast.show", text: I18n.t("js.converted_to_markdown")
    value = evaluate_textarea_value
    assert_match(/\|\s*Name\s*\|\s*Score\s*\|/, value)
    assert_match(/\|\s*-+\s*\|\s*-+\s*\|/, value)
    assert_match(/\|\s*Alice\s*\|\s*90\s*\|/, value)
  end

  test "clicking Convert to Markdown a second time, with nothing newly pasted, shows the toast instead of re-inserting" do
    users(:one).update!(table_paste_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    dispatch_paste(EXCEL_HTML, plain_text: "Name\tScore\nAlice\t90")
    find(".editor-fab-button").click
    click_on I18n.t("editor.fab.convert_table_paste")
    assert_match(/\|\s*Alice\s*\|\s*90\s*\|/, evaluate_textarea_value)

    value_after_first_convert = evaluate_textarea_value
    click_on I18n.t("editor.fab.convert_table_paste")

    assert_selector ".toast.show", text: I18n.t("js.table_paste.no_pending_table")
    assert_equal value_after_first_convert, evaluate_textarea_value
  end

  test "Convert to Markdown handles a merged (rowspan) header cell cleanly, without a phantom empty row" do
    users(:one).update!(table_paste_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    dispatch_paste(EXCEL_ROWSPAN_HEADER_HTML, plain_text: "group\tcount\n\nsample\t18")
    find(".editor-fab-button").click
    click_on I18n.t("editor.fab.convert_table_paste")

    value = evaluate_textarea_value
    assert_match(/\|\s*group\s*\|\s*count\s*\|/, value)
    assert_match(/\|\s*-+\s*\|\s*-+\s*\|/, value)
    assert_match(/\|\s*sample\s*\|\s*18\s*\|/, value)
    # The row the rowspan header merges into has no cells of its own —
    # it must not resurface as a separate, blank table row.
    assert_no_match(/^\s*\|\s*\|\s*\|\s*$/, value)
  end

  test "Convert to Markdown keeps every row's column count consistent for a colspan-grouped header" do
    users(:one).update!(table_paste_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    dispatch_paste(EXCEL_COLSPAN_HEADER_HTML, plain_text: "Group A\t\tGroup B\t\nName\tScore\tName\tScore\nAlice\t90\tBob\t85")
    find(".editor-fab-button").click
    click_on I18n.t("editor.fab.convert_table_paste")

    value = evaluate_textarea_value
    table_rows = value.lines.map(&:strip).select { |line| line.start_with?("|") }
    assert_equal 4, table_rows.size, "expected a header, a separator, and two data rows:\n#{table_rows.join("\n")}"

    column_counts = table_rows.map { |row| row.count("|") }
    assert_equal 1, column_counts.uniq.size,
      "every row must have the same column count — the colspan header must not leave later rows misaligned:\n#{table_rows.join("\n")}"

    assert_match(/Alice.*90.*Bob.*85/, table_rows.last)
  end

  test "Convert to Markdown promotes the real header, not a full-width title row" do
    users(:one).update!(table_paste_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    dispatch_paste(EXCEL_TITLE_ROW_HTML, plain_text: "Summary\nName\tScore\nAlice\t90")
    find(".editor-fab-button").click
    click_on I18n.t("editor.fab.convert_table_paste")

    value = evaluate_textarea_value
    assert_match(/\|\s*Alice\s*\|\s*90\s*\|/, value)

    # The title must not have become the column header — a duplicated
    # "Summary" body row further down is fine; what matters is the <thead>.
    table_rows = value.lines.map(&:strip).select { |line| line.start_with?("|") }
    assert_equal "| Name | Score |", table_rows.first
    assert_match(/^\|\s*-+\s*\|\s*-+\s*\|$/, table_rows.second)
  end

  test "pasting a plain image, with no HTML alongside it, is still handled as an image upload" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    page.driver.browser.execute_script(<<~JS)
      const bytes = Uint8Array.from(atob("#{SAMPLE_PNG_BASE64}"), (c) => c.charCodeAt(0))
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(new File([bytes], "photo.png", { type: "image/png" }))

      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
    JS

    uploading_marker = I18n.t("js.image_upload.uploading", filename: "photo.png")
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.1 until evaluate_textarea_value.include?(uploading_marker) }
  end

  test "plain-text paste with no real formatting is left alone" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    prevented = dispatch_paste("<span>just plain text</span>", plain_text: "just plain text")

    # A synthetic dispatchEvent doesn't trigger native paste-insertion, so
    # the verifiable signal here is whether our handler stayed out of the way.
    assert_not prevented
    assert_no_selector ".toast.show", text: I18n.t("js.converted_to_markdown")
  end

  private

  # Builds a real ClipboardEvent with clipboard HTML (and optionally
  # plain text) and dispatches it at the textarea. Returns whether the
  # handler called preventDefault.
  def dispatch_paste(html, plain_text: nil)
    page.driver.browser.execute_script(<<~JS, html, plain_text)
      const [html, plainText] = arguments
      const dataTransfer = new DataTransfer()
      dataTransfer.setData("text/html", html)
      if (plainText) dataTransfer.setData("text/plain", plainText)

      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
      return event.defaultPrevented
    JS
  end

  # Same idea as dispatch_paste, but the DataTransfer also carries a
  # File simulating Excel/Sheets' rendered-selection image — the trigger
  # for the image-hijack bug this file guards against.
  def dispatch_paste_with_image(html, plain_text:, image_base64:)
    page.driver.browser.execute_script(<<~JS, html, plain_text, image_base64)
      const [html, plainText, imageBase64] = arguments
      const bytes = Uint8Array.from(atob(imageBase64), (c) => c.charCodeAt(0))

      const dataTransfer = new DataTransfer()
      dataTransfer.setData("text/html", html)
      dataTransfer.setData("text/plain", plainText)
      dataTransfer.items.add(new File([bytes], "image.png", { type: "image/png" }))

      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
    JS
  end

  def evaluate_textarea_value
    page.evaluate_script("document.querySelector(\"textarea[name='note[content]']\").value")
  end
end

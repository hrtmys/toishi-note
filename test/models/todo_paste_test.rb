require "test_helper"

# TodoPaste is pure: text in, structured lines out. Pins the grammar from
# tmp/plans/todos-hub/pr3/plan.md section 1 — right-to-left parsing, the
# fail-closed command suffix, and what gets ignored outright.
class TodoPasteTest < ActiveSupport::TestCase
  test "parses a plain unchecked line under its heading" do
    result = TodoPaste.parse(<<~MD)
      ## Groceries
      - [ ] Buy milk
    MD

    line = result.lines.sole
    assert_equal "Groceries", line.heading
    assert_equal "Buy milk", line.content
    assert_not line.checked
    assert_nil line.id
    assert_nil line.due
  end

  test "parses a checked line, a due date, and an id together" do
    result = TodoPaste.parse(<<~MD)
      ## Groceries
      - [x] Buy milk (due: 2026-09-01) (id: c8)
    MD

    line = result.lines.sole
    assert line.checked
    assert_equal "Buy milk", line.content
    assert_equal Date.new(2026, 9, 1), line.due
    assert_equal 12 * 36 + 8, line.id # "c8" base36
  end

  test "an id-only line has no due" do
    result = TodoPaste.parse("## G\n- [ ] Buy milk (id: c8)")
    line = result.lines.sole
    assert_equal "Buy milk", line.content
    assert_nil line.due
    assert_not_nil line.id
  end

  test "a line with neither due nor id parses to plain content" do
    result = TodoPaste.parse("## G\n- [ ] Buy milk")
    line = result.lines.sole
    assert_equal "Buy milk", line.content
    assert_nil line.due
    assert_nil line.id
  end

  test "a due-tag shape in the middle of content is left untouched" do
    result = TodoPaste.parse("## G\n- [ ] Renew (due: 2020-01-01) before it expires (id: c8)")
    line = result.lines.sole
    assert_equal "Renew (due: 2020-01-01) before it expires", line.content
    assert_nil line.due
  end

  test "content ending in a due-tag shape on a line that also has a real due tag: the real tag wins, the fake stays in content" do
    result = TodoPaste.parse("## G\n- [ ] Buy milk (due: 2020-01-01) (due: 2026-09-01) (id: c8)")
    line = result.lines.sole
    assert_equal "Buy milk (due: 2020-01-01)", line.content
    assert_equal Date.new(2026, 9, 1), line.due
  end

  test "a doubled due tag strips only the last one, leaving the other in content" do
    result = TodoPaste.parse("## G\n- [ ] Task (due: 2020-01-01) (due: 2026-09-01)")
    line = result.lines.sole
    assert_equal "Task (due: 2020-01-01)", line.content
    assert_equal Date.new(2026, 9, 1), line.due
  end

  test "(due: none) parses as the clearing marker, distinct from an absent due" do
    result = TodoPaste.parse("## G\n- [ ] Buy milk (due: none) (id: c8)")
    assert_equal :none, result.lines.sole.due
  end

  test "ignores the preamble prose before any heading" do
    result = TodoPaste.parse(<<~MD)
      This is a snapshot of open tasks from Toishi Note, for handing off to an AI assistant.

      Each task is one line: `- [ ] task (due: YYYY-MM-DD) (id: c8)`.

      ## Groceries
      - [ ] Buy milk (id: c8)
    MD

    assert_equal [ "Buy milk" ], result.lines.map(&:content)
  end

  test "ignores everything under Structure until the next heading" do
    result = TodoPaste.parse(<<~MD)
      ## Structure
      Notebook A / Folder A / Groceries (1 open)
      Notebook A / Folder A / Chores (0 open)

      ## Groceries
      - [ ] Buy milk (id: c8)
    MD

    assert_equal [ "Buy milk" ], result.lines.map(&:content)
    assert_equal [ "Groceries" ], result.lines.map(&:heading)
  end

  test "ignores everything between <details> and </details>" do
    result = TodoPaste.parse(<<~MD)
      ## Groceries
      - [ ] Buy milk (id: c8)

      <details><summary>Recently done (7 days)</summary>

      - [x] Old task (id: c9)

      </details>
    MD

    assert_equal [ "Buy milk" ], result.lines.map(&:content)
  end

  test "ignores the excluded line in English" do
    result = TodoPaste.parse("## Groceries\n- [ ] Buy milk (id: c8)\n\n1 excluded")
    assert_equal [ "Buy milk" ], result.lines.map(&:content)
  end

  test "ignores the excluded line in Japanese" do
    result = TodoPaste.parse("## Groceries\n- [ ] Buy milk (id: c8)\n\n1件を除外中")
    assert_equal [ "Buy milk" ], result.lines.map(&:content)
  end

  test "ignores arbitrary AI commentary between sections" do
    result = TodoPaste.parse(<<~MD)
      ## Groceries
      - [ ] Buy milk (id: c8)

      I've reviewed your tasks and marked the completed ones below.

      ## Chores
      - [ ] Mow lawn (id: c9)
    MD

    assert_equal [ "Buy milk", "Mow lawn" ], result.lines.map(&:content)
  end

  test "any line that is not a task line is not a line" do
    result = TodoPaste.parse(<<~MD)
      ## Groceries
      Some prose about groceries.
      - [ ] Buy milk (id: c8)
      * Not a checkbox marker
    MD

    assert_equal [ "Buy milk" ], result.lines.map(&:content)
  end

  # --- fail-closed command suffix table --------------------------------

  [
    "(id: ;delete!)",
    "(id: c8;delete!;delete!)",
    "(id: c8;DELETE!)",
    "(id: c8 ; delete!)",
    "(id: c8;del!)"
  ].each do |malformed|
    test "malformed suffix #{malformed.inspect} stays inert content, no delete command" do
      result = TodoPaste.parse("## G\n- [ ] Buy milk #{malformed}")
      line = result.lines.sole
      assert_not line.delete?, "expected no delete command for #{malformed.inspect}"
      assert_includes line.content, malformed
    end
  end

  test "the exact valid suffix ;delete! is recognized" do
    result = TodoPaste.parse("## G\n- [ ] Buy milk (id: c8;delete!)")
    line = result.lines.sole
    assert line.delete?
    assert_equal "Buy milk", line.content
    assert_not_nil line.id
  end

  test "content legitimately ending (delete) is not a delete command" do
    result = TodoPaste.parse("## G\n- [ ] Clean up old backup files (delete) (id: c8)")
    line = result.lines.sole
    assert_not line.delete?
    assert_includes line.content, "(delete)"
  end

  test "content legitimately ending (action: delete) is not a delete command" do
    result = TodoPaste.parse("## G\n- [ ] Clean up old backup files (action: delete) (id: c8)")
    line = result.lines.sole
    assert_not line.delete?
    assert_includes line.content, "(action: delete)"
  end

  test "(id: notbase36;delete!) decodes as ordinary (if bogus) base36 rather than being special-cased" do
    result = TodoPaste.parse("## G\n- [ ] Buy milk (id: notbase36;delete!)")
    line = result.lines.sole
    assert line.delete?
    assert_not_nil line.id
  end

  # --- adversarial input, never 500 -------------------------------------

  test "empty input parses to no lines" do
    assert_equal [], TodoPaste.parse("").lines
  end

  test "whitespace-only input parses to no lines" do
    assert_equal [], TodoPaste.parse("   \n\t\n  ").lines
  end

  test "a truncated line parses to no lines rather than raising" do
    assert_nothing_raised { TodoPaste.parse("## G\n- [ ] Buy milk (due: 2026-09").lines }
  end

  test "a lone ## with no title and no body parses to no lines" do
    assert_nothing_raised do
      result = TodoPaste.parse("##")
      assert_equal [], result.lines
    end
  end

  test "raw HTML input parses to no lines rather than raising" do
    assert_nothing_raised do
      result = TodoPaste.parse("<script>alert(1)</script><div>hi</div>")
      assert_equal [], result.lines
    end
  end

  test "a 500KB string does not raise" do
    huge = "## G\n" + ("- [ ] filler task\n" * 30_000)
    assert_operator huge.bytesize, :>, 500_000
    assert_nothing_raised { TodoPaste.parse(huge) }
  end

  test "parsing more than MAX_PASTE_LINES task lines does not raise" do
    body = (1..(TodoPaste::MAX_PASTE_LINES + 1)).map { |n| "- [ ] task #{n}" }.join("\n")
    assert_nothing_raised { TodoPaste.parse("## G\n#{body}") }
  end
end

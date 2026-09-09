require "test_helper"

class PositionedTest < ActiveSupport::TestCase
  # Notebook/Folder are real Positioned includers, exercised directly
  # here rather than through a fake.
  test "reposition! assigns sequential positions in the given order" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    a = notebook.folders.create!(name: "A")
    b = notebook.folders.create!(name: "B")
    c = notebook.folders.create!(name: "C")

    Positioned.reposition!(notebook.folders, [ c.id, a.id, b.id ])

    assert_equal 1, c.reload.position
    assert_equal 2, a.reload.position
    assert_equal 3, b.reload.position
  end

  test "reposition! raises when the id set is missing a member of the relation" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    a = notebook.folders.create!(name: "A")
    notebook.folders.create!(name: "B")

    assert_raises(ActiveRecord::RecordNotFound) do
      Positioned.reposition!(notebook.folders, [ a.id ])
    end
  end

  test "reposition! raises when the id set includes something outside the relation, and touches nothing" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    a = notebook.folders.create!(name: "A")
    foreign_folder = users(:two).notebooks.create!(name: "Other").folders.create!(name: "Foreign")

    assert_raises(ActiveRecord::RecordNotFound) do
      Positioned.reposition!(notebook.folders, [ a.id, foreign_folder.id ])
    end

    assert_equal 1, a.reload.position, "the in-scope record should be untouched by a rejected call"
    assert_equal 1, foreign_folder.reload.position, "a foreign record must never be written to, even if it's included in the (invalid) request"
  end

  test "reposition! with an empty id set on an empty scope is a silent no-op" do
    notebook = users(:one).notebooks.create!(name: "Empty Notebook")

    assert_nothing_raised do
      Positioned.reposition!(notebook.folders, [])
    end
  end

  test "reposition! raises on duplicated ids, and touches nothing" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    a = notebook.folders.create!(name: "A")
    b = notebook.folders.create!(name: "B")

    assert_raises(ActiveRecord::RecordNotFound) do
      Positioned.reposition!(notebook.folders, [ a.id, a.id ])
    end

    assert_equal [ 1, 2 ], [ a.reload.position, b.reload.position ]
  end

  test "reposition! works in a todo_items scope, not just folders" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    folder = notebook.folders.create!(name: "Folder")
    note = folder.notes.create!(notebook: notebook, title: "Todos", note_type: "todo")
    x = note.todo_items.create!(content: "X")
    y = note.todo_items.create!(content: "Y")

    Positioned.reposition!(note.todo_items, [ y.id, x.id ])

    assert_equal 1, y.reload.position
    assert_equal 2, x.reload.position
  end

  test "reposition! raises, inside its own transaction, if a sibling is destroyed after the caller's own id-set check" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    a = notebook.folders.create!(name: "A")
    b = notebook.folders.create!(name: "B")
    ids = notebook.folders.ids # a caller might validate against this and then race a concurrent destroy

    b.destroy!

    assert_raises(ActiveRecord::RecordNotFound) do
      Positioned.reposition!(notebook.folders, ids)
    end
    assert_equal 1, a.reload.position, "the surviving record must be untouched when the re-checked id set no longer matches"
  end
end

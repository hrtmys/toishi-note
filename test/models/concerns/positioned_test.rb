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
end

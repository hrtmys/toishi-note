require "test_helper"

class NotebookTest < ActiveSupport::TestCase
  test "valid with a name and an owner" do
    notebook = Notebook.new(name: "My Notebook", user: users(:one))
    assert notebook.valid?
  end

  test "invalid without a name" do
    notebook = Notebook.new(name: nil, user: users(:one))
    assert_not notebook.valid?
    assert_includes notebook.errors[:name], "can't be blank"
  end

  test "invalid without a user" do
    notebook = Notebook.new(name: "Orphan Notebook")
    assert_not notebook.valid?
    assert_includes notebook.errors[:user], "must exist"
  end

  test "destroying a notebook destroys its folders" do
    notebook = users(:one).notebooks.create!(name: "Destroy Me")
    notebook.folders.create!(name: "Child Folder")

    assert_difference("Folder.count", -1) do
      notebook.destroy
    end
  end

  test "destroying a notebook destroys its notes" do
    notebook = users(:one).notebooks.create!(name: "Destroy Me")
    folder = notebook.folders.create!(name: "Child Folder")
    folder.notes.create!(notebook: notebook, title: "Child Note", note_type: "md")

    assert_difference("Note.count", -1) do
      notebook.destroy
    end
  end

  test "position is assigned automatically, appended after existing siblings" do
    # notebooks(:one) already occupies position 1 for users(:one).
    second = users(:one).notebooks.create!(name: "Second")
    assert_equal 2, second.position
  end

  test "position numbering is scoped to the user, not global" do
    # Push the global max position up via users(:one); users(:admin)'s
    # first notebook should still start at 1, not the table's global max.
    users(:one).notebooks.create!(name: "Another for user one")
    theirs = users(:admin).notebooks.create!(name: "First for admin")

    assert_equal 1, theirs.position
  end

  test "an explicitly assigned position is not overwritten" do
    notebook = users(:one).notebooks.create!(name: "Pre-positioned", position: 99)
    assert_equal 99, notebook.position
  end

  test "user.notebooks is ordered by position, not creation order" do
    created_first_but_positioned_last = users(:two).notebooks.create!(name: "Created first", position: 3)
    created_second_but_positioned_first = users(:two).notebooks.create!(name: "Created second", position: 2)

    assert_equal [ notebooks(:two), created_second_but_positioned_first, created_first_but_positioned_last ], users(:two).notebooks.to_a
  end
end

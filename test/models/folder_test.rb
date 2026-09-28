require "test_helper"

class FolderTest < ActiveSupport::TestCase
  setup do
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
  end

  test "valid with a notebook and a name" do
    folder = @notebook.folders.new(name: "My Folder")
    assert folder.valid?
  end

  test "invalid without a name" do
    folder = @notebook.folders.new(name: nil)
    assert_not folder.valid?
    assert_includes folder.errors[:name], "can't be blank"
  end

  test "invalid without a notebook" do
    folder = Folder.new(name: "Orphan Folder")
    assert_not folder.valid?
    assert_includes folder.errors[:notebook], "must exist"
  end

  test "destroying a folder destroys its notes" do
    folder = @notebook.folders.create!(name: "Destroy Me")
    folder.notes.create!(notebook: @notebook, title: "Child Note", note_type: "md")

    assert_difference("Note.count", -1) do
      folder.destroy
    end
  end

  test "position is assigned automatically, appended after existing siblings" do
    first = @notebook.folders.create!(name: "First")
    second = @notebook.folders.create!(name: "Second")

    assert_equal 1, first.position
    assert_equal 2, second.position
  end

  test "position numbering is scoped to the notebook, not global" do
    other_notebook = users(:one).notebooks.create!(name: "Other Notebook")

    @notebook.folders.create!(name: "In first notebook")
    folder_in_other_notebook = other_notebook.folders.create!(name: "In other notebook")

    assert_equal 1, folder_in_other_notebook.position
  end

  test "an explicitly assigned position is not overwritten" do
    folder = @notebook.folders.create!(name: "Pre-positioned", position: 99)
    assert_equal 99, folder.position
  end

  test "notebook.folders is ordered by position, not creation order" do
    created_first_but_positioned_last = @notebook.folders.create!(name: "Created first", position: 2)
    created_second_but_positioned_first = @notebook.folders.create!(name: "Created second", position: 1)

    assert_equal [ created_second_but_positioned_first, created_first_but_positioned_last ], @notebook.folders.to_a
  end

  test "move_to! updates the folder's own notebook" do
    folder = @notebook.folders.create!(name: "Movable")
    other_notebook = users(:one).notebooks.create!(name: "Other Notebook")

    folder.move_to!(other_notebook)

    assert_equal other_notebook, folder.reload.notebook
  end

  test "move_to! cascades to every child note's notebook_id" do
    folder = @notebook.folders.create!(name: "Movable")
    note_a = folder.notes.create!(notebook: @notebook, title: "A", note_type: "md")
    note_b = folder.notes.create!(notebook: @notebook, title: "B", note_type: "md")
    other_notebook = users(:one).notebooks.create!(name: "Other Notebook")

    folder.move_to!(other_notebook)

    assert_equal other_notebook, note_a.reload.notebook
    assert_equal other_notebook, note_b.reload.notebook
  end

  test "move_to! is a no-op when the target is already the current notebook" do
    folder = @notebook.folders.create!(name: "Stationary")

    assert_no_changes -> { folder.reload.updated_at } do
      folder.move_to!(@notebook)
    end
  end

  test "move_to! into a notebook with a folder at the same position appends it and closes the source gap" do
    [ "Movable", "フォルダ移動" ].each do |name|
      source = users(:one).notebooks.create!(name: "Source #{name}")
      stays = source.folders.create!(name: "Stays", position: 1)
      folder = source.folders.create!(name: name, position: 2)
      after = source.folders.create!(name: "After", position: 3)
      target = users(:one).notebooks.create!(name: "Target #{name}")
      target_first = target.folders.create!(name: "T1", position: 1)
      target_second = target.folders.create!(name: "T2", position: 2)

      folder.move_to!(target)

      assert_equal [ target_first, target_second, folder ], target.folders.reload.to_a
      assert_equal [ 1, 2, 3 ], target.folders.pluck(:position)
      assert_equal [ stays, after ], source.folders.reload.to_a
      assert_equal [ 1, 2 ], source.folders.pluck(:position)
    end
  end
end

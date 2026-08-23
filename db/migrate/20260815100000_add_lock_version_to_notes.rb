class AddLockVersionToNotes < ActiveRecord::Migration[8.1]
  def change
    # Rails' optimistic locking activates automatically for a column
    # named lock_version. Closes a bug where two devices editing the
    # same note could silently overwrite each other's autosave.
    add_column :notes, :lock_version, :integer, default: 0, null: false
  end
end

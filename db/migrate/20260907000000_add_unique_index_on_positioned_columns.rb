class AddUniqueIndexOnPositionedColumns < ActiveRecord::Migration[8.1]
  # Defense in depth alongside the row-locking fix in Positioned: even if a
  # future code path ever bypasses the lock, the database itself now
  # refuses two siblings under the same parent sharing a position.
  def change
    remove_index :folders, :notebook_id
    add_index :folders, [ :notebook_id, :position ], unique: true

    remove_index :notebooks, :user_id
    add_index :notebooks, [ :user_id, :position ], unique: true

    remove_index :scrap_items, :note_id
    add_index :scrap_items, [ :note_id, :position ], unique: true

    remove_index :todo_items, :note_id
    add_index :todo_items, [ :note_id, :position ], unique: true
  end
end

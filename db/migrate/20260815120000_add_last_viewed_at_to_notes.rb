class AddLastViewedAtToNotes < ActiveRecord::Migration[8.1]
  def change
    # Tracks pure view history for the Ctrl+P palette's most-recently-
    # viewed ordering. Its own column, separate from updated_at, so
    # merely reading a note never corrupts the sidebar's default order.
    add_column :notes, :last_viewed_at, :datetime
    add_index :notes, :last_viewed_at
  end
end

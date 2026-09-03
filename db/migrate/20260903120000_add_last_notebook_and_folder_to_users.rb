class AddLastNotebookAndFolderToUsers < ActiveRecord::Migration[8.1]
  def change
    # Remembers where the user left off, so a fresh session (cache clear,
    # new device, the remote VPS restarting) resumes there instead of
    # always falling back to the first notebook/folder by position.
    add_column :users, :last_notebook_id, :integer
    add_column :users, :last_folder_id, :integer
    add_index :users, :last_notebook_id
    add_index :users, :last_folder_id
  end
end

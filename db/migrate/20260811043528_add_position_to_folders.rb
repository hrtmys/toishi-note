class AddPositionToFolders < ActiveRecord::Migration[8.1]
  def change
    add_column :folders, :position, :integer
  end
end

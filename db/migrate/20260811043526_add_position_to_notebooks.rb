class AddPositionToNotebooks < ActiveRecord::Migration[8.1]
  def change
    add_column :notebooks, :position, :integer
  end
end

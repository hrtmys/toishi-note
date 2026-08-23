class AddSourceToScrapItems < ActiveRecord::Migration[8.1]
  def change
    add_column :scrap_items, :source, :string
  end
end

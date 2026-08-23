class CreateScrapItems < ActiveRecord::Migration[8.1]
  def change
    create_table :scrap_items do |t|
      t.references :note, null: false, foreign_key: true
      t.text :content
      t.integer :position

      t.timestamps
    end
  end
end

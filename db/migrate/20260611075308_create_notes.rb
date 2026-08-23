class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.string :title
      t.string :note_type
      t.text :content
      t.boolean :is_pinned
      t.references :folder, null: false, foreign_key: true
      t.references :notebook, null: false, foreign_key: true

      t.timestamps
    end
  end
end

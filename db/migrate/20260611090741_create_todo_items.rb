class CreateTodoItems < ActiveRecord::Migration[8.1]
  def change
    create_table :todo_items do |t|
      t.references :note, null: false, foreign_key: true
      t.string :content
      t.boolean :is_checked
      t.integer :position

      t.timestamps
    end
  end
end

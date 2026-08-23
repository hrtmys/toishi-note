class DropTasks < ActiveRecord::Migration[8.1]
  def up
    drop_table :tasks, if_exists: true
  end

  def down
    create_table :tasks do |t|
      t.string :title, null: false
      t.datetime :due_date, null: false
      t.date :start_date, null: false
      t.string :priority
      t.text :details
      t.string :location
      t.string :link_url
      t.string :status
      t.integer :estimated_time
      t.integer :actual_time
      t.integer :performance
      t.datetime :completed_at
      t.timestamps
    end
    add_index :tasks, :start_date
    add_index :tasks, :completed_at
  end
end

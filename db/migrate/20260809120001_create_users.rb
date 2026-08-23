class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      # When this account was actually registered — kept distinct from
      # created_at so it stays meaningful even if a row is ever recreated
      # by a migration or an import.
      t.datetime :registered_at, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end

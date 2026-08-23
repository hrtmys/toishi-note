class AddTablePasteEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    # Off by default, same progressive-disclosure reasoning as
    # editor_fab_enabled/compare_enabled but independent of both — all
    # three share the same floating button.
    add_column :users, :table_paste_enabled, :boolean, default: false, null: false
  end
end

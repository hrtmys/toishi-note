class AddCompareEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    # Off by default, same progressive-disclosure reasoning as
    # editor_fab_enabled but independent of it — both share the FAB.
    add_column :users, :compare_enabled, :boolean, default: false, null: false
  end
end

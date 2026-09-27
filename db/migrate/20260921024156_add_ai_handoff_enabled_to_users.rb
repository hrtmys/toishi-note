class AddAiHandoffEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    # Off by default — progressive disclosure; see tmp/plans/todos-hub/STATUS.md.
    add_column :users, :ai_handoff_enabled, :boolean, default: false, null: false
  end
end

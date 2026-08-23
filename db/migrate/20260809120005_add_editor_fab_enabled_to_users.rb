class AddEditorFabEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    # Off by default, per the "progressive disclosure" design principle in
    # ux-roadmap.md.old — the AI-formatting FAB only appears once a user opts in
    # through Settings.
    add_column :users, :editor_fab_enabled, :boolean, default: false, null: false
  end
end

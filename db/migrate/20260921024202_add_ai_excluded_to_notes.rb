class AddAiExcludedToNotes < ActiveRecord::Migration[8.1]
  def change
    # Hides a note from both the Todos pane and the AI handoff; inert unless ai_handoff_enabled.
    add_column :notes, :ai_excluded, :boolean, default: false, null: false
  end
end

class TightenSchemaConstraintsAndAddTitleCustomized < ActiveRecord::Migration[8.1]
  # Local to this migration on purpose: ties behavior to the schema as it
  # was at this point in time, not wherever the real models are today.
  class Note < ActiveRecord::Base; end
  class TodoItem < ActiveRecord::Base; end
  class Notebook < ActiveRecord::Base; end
  class Folder < ActiveRecord::Base; end

  # Placeholder titles a note has never had explicitly set by a user —
  # matches Note#auto_set_title's old string-comparison check, which this
  # migration's backfill replaces with a real column.
  PLACEHOLDER_TITLES = [ "無題のノート", "無題のTODO", "無題のスクラップ" ].freeze

  def up
    # notes.is_pinned / todo_items.is_checked: nullable booleans worked
    # around by an after_initialize callback in each model — a real
    # column default makes both callbacks dead code, deleted here too.
    Note.where(is_pinned: nil).update_all(is_pinned: false)
    change_column_null :notes, :is_pinned, false
    change_column_default :notes, :is_pinned, false

    TodoItem.where(is_checked: nil).update_all(is_checked: false)
    change_column_null :todo_items, :is_checked, false
    change_column_default :todo_items, :is_checked, false

    # notes.note_type: "txt" was the old unset-type fallback, never a
    # real type. Folded into "md" along with genuinely NULL rows; the
    # enum added in this commit replaces the fallback going forward.
    Note.where(note_type: [ nil, "txt" ]).update_all(note_type: "md")
    change_column_null :notes, :note_type, false

    # notebooks.name / folders.name: both models validate presence, but
    # the schema didn't agree — a row from outside the app could slip a
    # NULL/blank name past that. Backfill with an untitled-Nth placeholder.
    backfill_blank_names(Notebook, "notebook")
    change_column_null :notebooks, :name, false

    backfill_blank_names(Folder, "folder")
    change_column_null :folders, :name, false

    # notes.title_customized: replaces the old approach of detecting "has
    # the user titled this?" by matching hardcoded Japanese placeholder
    # strings, which never worked for other locales.
    add_column :notes, :title_customized, :boolean, default: false, null: false
    Note.where.not(title: PLACEHOLDER_TITLES).update_all(title_customized: true)
  end

  def down
    remove_column :notes, :title_customized
    change_column_null :folders, :name, true
    change_column_null :notebooks, :name, true
    change_column_null :notes, :note_type, true
    change_column_default :todo_items, :is_checked, nil
    change_column_null :todo_items, :is_checked, true
    change_column_default :notes, :is_pinned, nil
    change_column_null :notes, :is_pinned, true
  end

  private

  def backfill_blank_names(klass, kind)
    klass.where(name: [ nil, "" ]).find_each.with_index(1) do |record, index|
      record.update_column(:name, "Untitled #{kind} #{index}")
    end
  end
end

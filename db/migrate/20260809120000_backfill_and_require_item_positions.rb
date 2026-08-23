class BackfillAndRequireItemPositions < ActiveRecord::Migration[8.1]
  # Local to this migration on purpose: referencing the real TodoItem/ScrapItem
  # models here would tie this migration's behavior to wherever those models
  # happen to be today, instead of the schema as it was at this point in time.
  class TodoItem < ActiveRecord::Base; end
  class ScrapItem < ActiveRecord::Base; end

  def up
    backfill_positions(TodoItem)
    backfill_positions(ScrapItem)

    change_column_null :todo_items, :position, false
    change_column_null :scrap_items, :position, false
  end

  def down
    change_column_null :todo_items, :position, true
    change_column_null :scrap_items, :position, true
  end

  private

  # Numbers every row 1..n per note, ordered by created_at, so existing data
  # ends up in the same order it already displayed in before `position`
  # was wired up.
  def backfill_positions(klass)
    klass.distinct.pluck(:note_id).each do |note_id|
      klass.where(note_id: note_id).order(:created_at).each_with_index do |item, index|
        item.update_column(:position, index + 1)
      end
    end
  end
end

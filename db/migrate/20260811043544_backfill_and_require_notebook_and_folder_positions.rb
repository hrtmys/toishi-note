class BackfillAndRequireNotebookAndFolderPositions < ActiveRecord::Migration[8.1]
  # Local to this migration on purpose: referencing the real Notebook/Folder
  # models here would tie this migration's behavior to wherever those models
  # happen to be today, instead of the schema as it was at this point in time.
  class Notebook < ActiveRecord::Base; end
  class Folder < ActiveRecord::Base; end

  def up
    backfill_positions(Notebook, :user_id)
    backfill_positions(Folder, :notebook_id)

    change_column_null :notebooks, :position, false
    change_column_null :folders, :position, false
  end

  def down
    change_column_null :notebooks, :position, true
    change_column_null :folders, :position, true
  end

  private

  # Numbers every row 1..n per parent, ordered by created_at, so existing
  # data ends up in the same order it already displayed in before
  # `position` was wired up.
  def backfill_positions(klass, parent_column)
    klass.distinct.pluck(parent_column).each do |parent_id|
      klass.where(parent_column => parent_id).order(:created_at).each_with_index do |record, index|
        record.update_column(:position, index + 1)
      end
    end
  end
end

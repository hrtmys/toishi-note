# A cross-notebook view of open TODOs — the one place items aren't
# scoped to a single note, so they need a due-date-first ordering of
# their own instead of the per-note position order.
class TodosController < ApplicationController
  def index
    @todo_items = Current.user.todo_items
      .where(is_checked: false)
      .includes(note: { folder: :notebook })
      # Note#todo_items already defaults to ordering by position —
      # reorder, not order, so this view's due-date-first order wins.
      .reorder(Arel.sql("due_date IS NULL, due_date ASC"))
  end
end

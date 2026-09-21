# Applies a TodoApplyPlan. One transaction, parent notes locked first,
# bang methods throughout — following Positioned.reposition! and
# Folder#move_to!, not TodoItemsController#bulk_create, which saves per
# record with no transaction and silently drops failures.
class TodoApplyPlanApplier
  DigestMismatch = Class.new(StandardError)

  # Re-parses and re-resolves +text+ inside the transaction so the plan
  # reflects the database as of right now, then aborts the whole apply if
  # that fresh plan's digest no longer matches what the preview showed.
  # Returns the applied plan, or nil on a digest mismatch.
  def self.apply!(text:, digest:, user:)
    plan = nil

    Note.transaction do
      plan = TodoApplyPlan.new(TodoPaste.parse(text).lines, user: user)
      lock_notes(plan, user)
      raise DigestMismatch unless TodoApplyPlanDigest.for(plan) == digest

      plan.operations.each { |op| apply_operation(op) }
    end

    plan
  rescue DigestMismatch
    nil
  end

  def self.lock_notes(plan, user)
    note_ids = plan.operations.filter_map { |op| op.note&.id }.uniq
    user.notes.where(id: note_ids).lock.pluck(:id) if note_ids.any?
  end
  private_class_method :lock_notes

  # Sets op.item to the created record on :add, so the controller can
  # render a turbo_stream for it without re-querying by content.
  def self.apply_operation(op)
    case op.type
    when :add then op.item = op.note.todo_items.create!(content: op.content, is_checked: !!op.checked, due_date: op.new_due)
    when :delete then op.item.destroy!
    when :check then op.item.update!(is_checked: op.checked)
    when :due_change then op.item.update!(due_date: op.new_due)
    end
  end
  private_class_method :apply_operation
end

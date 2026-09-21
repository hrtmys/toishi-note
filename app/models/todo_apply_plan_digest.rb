# A SHA256 over a plan's operations plus, for every item they touch, that
# item's current mutable attributes — so the apply can detect any change
# since the preview and refuse to act on stale data, without storing
# anything server-side between the two requests.
module TodoApplyPlanDigest
  def self.for(plan)
    Digest::SHA256.hexdigest(plan.operations.map { |op| signature(op) }.to_json)
  end

  def self.signature(op)
    parts = [ op.type, op.note&.id, op.item&.id, op.content, op.checked, op.old_due&.iso8601, op.new_due&.iso8601 ]
    parts + (op.item ? [ op.item.content, op.item.is_checked, op.item.due_date&.iso8601, op.item.updated_at.to_f ] : [])
  end
end

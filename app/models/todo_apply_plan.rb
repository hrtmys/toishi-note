# Resolves TodoPaste lines into operations against +user+'s data. Decides;
# never writes — see TodoApplyPlanApplier for the transactional write.
class TodoApplyPlan
  Operation = Struct.new(:type, :note, :item, :content, :checked, :old_due, :new_due, keyword_init: true)
  Skipped = Struct.new(:reason, :heading, keyword_init: true)

  attr_reader :operations, :skipped

  def initialize(lines, user:)
    @user = user
    @operations = []
    @skipped = []
    @seen_signatures = {}
    @heading_notes = {}

    lines.each { |line| process(line) }
  end

  private

  def process(line)
    signature = [ line.heading, line.checked, line.content, line.due, line.id, line.delete? ]
    if @seen_signatures[signature]
      @skipped << Skipped.new(reason: :duplicate_line, heading: line.heading)
      return
    end
    @seen_signatures[signature] = true

    item = bound_item(line)
    item ? process_bound(line, item) : process_unbound(line)
  end

  # Scoped through Current.user's association chain, never a bare find —
  # pasted text is hostile input that may carry another account's id.
  def bound_item(line)
    return nil if line.id.nil?

    @user.todo_items.find_by(id: line.id)
  rescue ActiveModel::RangeError, ActiveRecord::RangeError
    nil
  end

  def process_bound(line, item)
    stored_content = one_line(item.content)
    content_changed = line.content != stored_content

    if line.delete? && content_changed
      @skipped << Skipped.new(reason: :content_changed_with_marker, heading: line.heading)
      return
    end

    return @operations << Operation.new(type: :delete, note: item.note, item: item) if line.delete?

    content_changed ? process_rename(line, item) : process_in_place(line, item)
  end

  def process_rename(line, item)
    return skip_empty(line) if line.content.blank?

    note = resolve_note(line.heading)
    return if note.nil?

    @operations << Operation.new(type: :delete, note: item.note, item: item)
    @operations << Operation.new(type: :add, note: note, content: line.content, checked: line.checked, new_due: due_value(line.due))
  end

  def process_in_place(line, item)
    if line.checked != item.is_checked
      @operations << Operation.new(type: :check, note: item.note, item: item, checked: line.checked)
    end

    return if line.due.nil?

    new_due = due_value(line.due)
    return if new_due == item.due_date

    @operations << Operation.new(type: :due_change, note: item.note, item: item, old_due: item.due_date, new_due: new_due)
  end

  def process_unbound(line)
    if line.delete?
      @skipped << Skipped.new(reason: :unbound_marker, heading: line.heading)
      return
    end

    return skip_empty(line) if line.content.blank?

    note = resolve_note(line.heading)
    return if note.nil?

    @operations << Operation.new(type: :add, note: note, content: line.content, checked: line.checked, new_due: due_value(line.due))
  end

  def skip_empty(line)
    @skipped << Skipped.new(reason: :empty_content, heading: line.heading)
  end

  # Note titles aren't unique (PR2), so a heading resolves only when it
  # names exactly one note — no fuzzy matching, the issue's explicit rule.
  # Memoized so an ambiguous/unknown heading is reported once per group,
  # not once per line under it.
  def resolve_note(heading)
    return @heading_notes[heading] if @heading_notes.key?(heading)

    matches = @user.notes.where(title: heading, note_type: "todo").to_a
    note = matches.size == 1 ? matches.first : nil
    @skipped << Skipped.new(reason: matches.empty? ? :unknown_heading : :ambiguous_heading, heading: heading) if note.nil?
    @heading_notes[heading] = note
  end

  def due_value(due)
    due == :none ? nil : due
  end

  # PR2 collapses embedded newlines on export, so compare against the
  # same collapsed form or a genuinely multi-line item would never match.
  def one_line(text)
    text.to_s.gsub(/\r\n|\r|\n/, " ")
  end
end

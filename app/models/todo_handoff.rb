# Renders a user's open TODOs as Markdown for pasting into an AI chat.
# A PORO per NotebookExporter's precedent: it spans Notebook, Folder, Note
# and TodoItem, so it belongs in none of them.
class TodoHandoff
  # Structural text stays English: PR3's parser binds to it, so it must read
  # the same whatever locale the viewer is in.
  RECENTLY_DONE_WINDOW = 7.days

  PREAMBLE = <<~MD.strip
    This is a snapshot of open tasks from Toishi Note, for handing off to an AI assistant.

    Each task is one line: `- [ ] task (due: YYYY-MM-DD) (id: c8)`. The due date and id
    suffixes are omitted when absent. Keep the `(id: ...)` tag exactly as given on every
    line, including a line you want removed. To delete a task, add `;delete!` directly
    after the id inside the same parentheses, with no space: `(id: c8;delete!)`. Never
    remove the id tag itself. To clear a task's due date, write `(due: none)`. Notes
    excluded from AI handoff are not included below.
  MD

  def initialize(user:, scope: nil)
    @user = user
    @scope = scope
  end

  def to_markdown
    [ PREAMBLE, structure_section, task_sections, recently_done_section, excluded_line ]
      .compact.join("\n\n")
  end

  private

  def structure_section
    ([ "## Structure" ] + notes_in_scope.map { |note| structure_line(note) }).join("\n")
  end

  def structure_line(note)
    open_count = note.todo_items.count { |item| !item.is_checked? }
    "#{one_line(note.notebook.name)} / #{one_line(note.folder.name)} / #{one_line(note.title)} (#{open_count} open)"
  end

  def task_sections
    sections = notes_in_scope.filter_map { |note| task_section(note) }
    sections.join("\n\n").presence
  end

  def task_section(note)
    open_items = note.todo_items.reject(&:is_checked?)
    return if open_items.empty?

    ([ "## #{one_line(note.title)}" ] + open_items.map { |item| markdown_line_for(note, item) }).join("\n")
  end

  def recently_done_section
    lines = recently_done_lines
    return if lines.empty?

    ([ "<details><summary>Recently done (#{RECENTLY_DONE_WINDOW.inspect})</summary>", "" ] + lines + [ "</details>" ]).join("\n")
  end

  def recently_done_lines
    notes_in_scope.flat_map do |note|
      note.todo_items
        .select { |item| item.is_checked? && item.updated_at >= RECENTLY_DONE_WINDOW.ago }
        .map { |item| markdown_line_for(note, item) }
    end
  end

  def excluded_line
    return unless @user.ai_handoff_enabled? && excluded_count.positive?

    I18n.t("home.todos.excluded_count", count: excluded_count)
  end

  # The base36 id tag is appended after Note#todo_item_markdown_line — see
  # that method's comment for why its output itself must not change.
  def markdown_line_for(note, item)
    sanitized = item.dup
    sanitized.content = one_line(item.content)
    "#{note.todo_item_markdown_line(sanitized)} (id: #{item.id.to_s(36)})"
  end

  # Collapses embedded newlines so one item/name always renders as one
  # line — otherwise a hostile content or name could forge an extra line
  # (a fake task, a fake "##" heading, a fake Structure row).
  def one_line(text)
    text.to_s.gsub(/\r\n|\r|\n/, " ")
  end

  def notes_in_scope
    @notes_in_scope ||= begin
      scope = @user.ai_handoff_enabled? ? base_scope.where(ai_excluded: false) : base_scope
      scope.select { |note| note.todo_items.any? }
        .sort_by { |note| [ note.notebook.name, note.folder.name, note.title ] }
    end
  end

  def excluded_count
    return 0 unless @user.ai_handoff_enabled?

    base_scope.where(ai_excluded: true).to_a.count { |note| note.loaded_open_todo_items.any? }
  end

  def base_scope
    @base_scope ||= scoped_notes.where(note_type: "todo").includes(:notebook, :folder, :todo_items)
  end

  def scoped_notes
    case @scope
    when Notebook then @scope.notes
    when Folder then @scope.notes
    when Note then @user.notes.where(id: @scope.id)
    else @user.notes
    end
  end
end

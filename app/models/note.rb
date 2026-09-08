class Note < ApplicationRecord
  include Exportable

  belongs_to :notebook
  belongs_to :folder

  has_many :todo_items, -> { order(:position) }, dependent: :destroy
  has_many :scrap_items, -> { order(:position) }, dependent: :destroy
  has_many_attached :images

  # String-backed (not the default integer) so values already stored in
  # the column keep meaning without a data migration; just adds Note.md,
  # note.md?, etc. Old "txt" fallback was folded into "md" by migration.
  enum :note_type, { md: "md", todo: "todo", scrap: "scrap" }, default: "md"

  validates :title, presence: true
  # The enum's default only applies when note_type is genuinely unset —
  # an explicit `note_type: nil` sails past it and the enum's own
  # ArgumentError guard, so this catches it with a normal validation error.
  validates :note_type, presence: true

  # The palette's and the home page's shared "resting state": the 10 most
  # recently viewed notes, most recent first. reorder (not order) is
  # needed because notebooks already declares a default order scope that
  # a plain #order would only append to.
  scope :recently_viewed, -> { includes(:notebook, :folder).reorder(last_viewed_at: :desc).limit(10) }

  before_validation :auto_set_title

  def self.default_title_for(note_type)
    I18n.t("notes.default_title.#{note_type}", default: I18n.t("notes.default_title.md"))
  end

  # Ranks +scope+ (an already Current.user-scoped relation) against a
  # search +query+ for the command palette: exact-prefix title matches
  # first, then everything else, each group most-recently-viewed first.
  # A blank query falls back to the palette's normal resting state — the
  # 10 most recently viewed notes.
  def self.search_ranked(scope, query)
    return scope.recently_viewed if query.blank?

    like = "%#{sanitize_sql_like(query)}%"
    # Capped at 50 candidates before the Ruby-side sort — this app's
    # audience is too small for that to matter, and it keeps the
    # exact-prefix-first ranking simple without raw SQL.
    candidates = scope.where("title LIKE ? ESCAPE '\\'", like).limit(50).to_a

    prefix_matches, other_matches = candidates.partition { |note| note.title.downcase.start_with?(query.downcase) }
    by_recency = ->(note) { note.last_viewed_at || Time.at(0) }

    (prefix_matches.sort_by(&by_recency).reverse + other_matches.sort_by(&by_recency).reverse).first(10)
  end

  # Shared "brand new note living in this folder" factory — both a fresh
  # note (NotesController#create, empty content) and a promoted scrap
  # (ScrapItemsController#promote, content: the scrap's own content) need
  # the exact same title/note_type/notebook wiring, just different
  # note_type/content inputs.
  def self.create_in_folder!(folder:, notebook:, note_type:, content:)
    folder.notes.create!(
      notebook: notebook,
      title: default_title_for(note_type),
      note_type: note_type,
      content: content
    )
  end

  def todo_items_total_count
    todo_items_counts_by_checked.values.sum
  end

  def todo_items_completed_count
    todo_items_counts_by_checked[true] || 0
  end

  def todo_completion_percentage
    total = todo_items_total_count
    return 0 if total.zero?

    (todo_items_completed_count.to_f / total * 100).round
  end

  # Parses a pasted JSON array of bulk-import entries (strings, or objects
  # with "content" and an optional checked flag). Parsing is deliberately
  # kept separate from #build_bulk_todo_items below so a caller can enforce
  # an entry-count cap against the raw array before it bothers
  # instantiating a batch of records. Malformed JSON, or JSON that isn't an
  # array, parses to an empty array rather than raising.
  def self.parse_bulk_todo_entries(raw_json)
    parsed = JSON.parse(raw_json.to_s)
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end

  # Builds (but does not save) a TodoItem on this note for each valid entry
  # in +entries+ (as returned by .parse_bulk_todo_entries), silently
  # skipping malformed or blank ones. The caller decides how to persist
  # the result — see TodoItemsController#bulk_create.
  def build_bulk_todo_items(entries)
    entries.filter_map { |entry| build_bulk_todo_item(entry) }
  end

  # Converts this note to its exported Markdown form. TODO/Scrap are
  # structured data with fixed conversion rules — md notes are already
  # Markdown, so they pass through unchanged.
  def to_markdown
    case note_type
    when "todo"
      todo_items.map { |item| todo_item_markdown_line(item) }.join("\n")
    when "scrap"
      scrap_items.map(&:content).join("\n\n---\n\n")
    else
      content.to_s
    end
  end

  def export_filename
    "#{export_basename}.md"
  end

  # Attaches a pasted/dropped image, auto-converting to WebP unless the
  # uploader opted out (Settings > Editor). Returns the attached blob.
  def attach_uploaded_image(uploaded_file, compress:)
    if compress
      converted = ImageProcessing::Vips.source(uploaded_file.to_io).convert("webp").call
      basename = File.basename(uploaded_file.original_filename.to_s, ".*").presence || "image"
      images.attach(io: converted, filename: "#{basename}.webp", content_type: "image/webp")
    else
      images.attach(io: uploaded_file.to_io, filename: uploaded_file.original_filename, content_type: uploaded_file.content_type)
    end

    images.last
  end

  private

  # Single grouped-COUNT query, memoized per note instance, so a render
  # that asks for both the total and the completed count (e.g. the
  # todo-progress partial) issues one query instead of two or three.
  def todo_items_counts_by_checked
    @todo_items_counts_by_checked ||= todo_items.group(:is_checked).count
  end

  def export_display_name
    title
  end

  def todo_item_markdown_line(item)
    checkbox = item.is_checked? ? "[x]" : "[ ]"
    due = item.due_date ? " (due: #{item.due_date.iso8601})" : ""
    "- #{checkbox} #{item.content}#{due}"
  end

  def build_bulk_todo_item(entry)
    content, checked =
      case entry
      when String
        [ entry, false ]
      when Hash
        [ entry["content"], entry.values_at("checked", "is_checked", "done").compact.first ]
      end

    return if content.to_s.strip.blank?

    todo_items.build(content: content.to_s.strip, is_checked: !!checked)
  end

  def auto_set_title
    # Clearing the title hands control back to auto-titling, so a blanked
    # title re-derives from content (or the placeholder) on this and later
    # saves instead of staying locked as customized.
    self.title_customized = false if title.blank?

    # title_customized replaces an old placeholder-text comparison that
    # misfired on a locale switch. Gated to !persisted? so a later save
    # never re-runs this against the current locale's placeholder.
    if !persisted? && !title_customized? && title.present? && title != self.class.default_title_for(note_type)
      self.title_customized = true
    end

    if !title_customized? && content.present? && md?
      first_line = content.lines.reject(&:blank?).first
      self.title = first_line.strip.truncate(30) if first_line
    end

    # Fall back to the placeholder title if it's still blank after the above.
    self.title = self.class.default_title_for(note_type) if title.blank?
  end
end

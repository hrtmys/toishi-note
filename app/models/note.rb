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

  before_validation :auto_set_title

  def self.default_title_for(note_type)
    I18n.t("notes.default_title.#{note_type}", default: I18n.t("notes.default_title.md"))
  end

  def todo_items_total_count
    todo_items.count
  end

  def todo_items_completed_count
    todo_items.where(is_checked: true).count
  end

  def todo_completion_percentage
    return 0 if todo_items_total_count.zero?

    (todo_items_completed_count.to_f / todo_items_total_count * 100).round
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

  def export_display_name
    title
  end

  def todo_item_markdown_line(item)
    checkbox = item.is_checked? ? "[x]" : "[ ]"
    due = item.due_date ? " (due: #{item.due_date.iso8601})" : ""
    "- #{checkbox} #{item.content}#{due}"
  end

  def auto_set_title
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

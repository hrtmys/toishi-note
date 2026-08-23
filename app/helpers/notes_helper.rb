module NotesHelper
  NOTE_TYPE_ICONS = {
    "md" => "bi-filetype-md",
    "todo" => "bi-check2-square",
    "scrap" => "bi-pin-angle"
  }.freeze
  DEFAULT_NOTE_ICON = "bi-file-earmark-text"

  def note_icon_class(note)
    NOTE_TYPE_ICONS.fetch(note.note_type, DEFAULT_NOTE_ICON)
  end
end

# Shared "turn this record's name into a filesystem-safe filename" logic
# for Export (Notes, Notebooks).
module Exportable
  extend ActiveSupport::Concern

  # Strips filesystem-invalid characters but leaves the name intact —
  # String#parameterize would strip non-Latin script, emptying most
  # titles in a Japanese-first app.
  def export_basename
    sanitized = export_display_name.to_s.strip.gsub(%r{[/\\:*?"<>|]}, "_")
    sanitized.presence&.truncate(60, omission: "") || "untitled"
  end
end

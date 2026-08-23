# Bundles every note in a notebook into a single .zip of .md files,
# organized by folder. A PORO rather than Notebook#to_zip since this
# genuinely spans Notebook, Folder, and Note.
class NotebookExporter
  def initialize(notebook)
    @notebook = notebook
  end

  def filename
    "#{@notebook.export_basename}.zip"
  end

  def to_zip
    buffer = Zip::OutputStream.write_buffer do |zip|
      @notebook.folders.includes(:notes).each do |folder|
        entry_names_in_folder = Set.new

        folder.notes.each do |note|
          entry_name = unique_entry_name(folder, note, entry_names_in_folder)
          zip.put_next_entry(entry_name)
          zip.write(note.to_markdown)
        end
      end
    end

    buffer.rewind
    buffer.read
  end

  private

  # Two notes in the same folder can share a title, so a plain path could
  # silently overwrite one export with another — number duplicates instead.
  def unique_entry_name(folder, note, seen)
    base = "#{folder.export_basename}/#{note.export_basename}"
    name = "#{base}.md"

    suffix = 1
    while seen.include?(name)
      suffix += 1
      name = "#{base} (#{suffix}).md"
    end

    seen << name
    name
  end
end

class Folder < ApplicationRecord
  include Exportable
  include Positioned

  belongs_to :notebook
  positioned_within :notebook

  # Deleting a folder cascades to its notes, so none are orphaned.
  has_many :notes, dependent: :destroy

  validates :name, presence: true

  # Reparents this folder to +notebook+ — a drag-and-drop move between
  # notebooks. notes' notebook_id is a separate, denormalized FK, so it
  # must be cascaded explicitly here.
  def move_to!(notebook)
    transaction do
      # lock! reloads with a row lock, so this serializes against any other
      # request (e.g. NotesController#create) that locks this same folder
      # row before reading/writing anything derived from its notebook_id.
      # (See app/models/concerns/positioned.rb for why `.lock`/`lock!`
      # genuinely serializes here even though SQLite drops the `FOR
      # UPDATE` SQL itself.)
      lock!
      return if notebook_id == notebook.id

      update!(notebook: notebook)
      notes.update_all(notebook_id: notebook.id)
    end
  end

  private

  def export_display_name
    name
  end
end

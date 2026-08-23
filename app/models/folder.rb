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
    return if notebook_id == notebook.id

    transaction do
      update!(notebook: notebook)
      notes.update_all(notebook_id: notebook.id)
    end
  end

  private

  def export_display_name
    name
  end
end

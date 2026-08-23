class Notebook < ApplicationRecord
  include Exportable
  include Positioned

  belongs_to :user
  positioned_within :user

  has_many :folders, -> { order(:position) }, dependent: :destroy
  has_many :notes, dependent: :destroy

  validates :name, presence: true

  private

  def export_display_name
    name
  end
end
